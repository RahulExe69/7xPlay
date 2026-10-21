package dev.beamlak.flixquest_v2.downloads

import android.net.Uri
import android.util.AtomicFile
import androidx.media3.common.StreamKey
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.Downloader
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID

/** Atomic checkpoints keep background downloads and offline playback on the same refreshed request.
 * Media3's original request remains its job identity; its stream keys must never merge with new indexes.
 */
@UnstableApi
internal class DownloadRecoveryState(private val directory: File) {
    private fun file(id: String): AtomicFile = AtomicFile(File(directory, id.toByteArray().joinToString("") { "%02x".format(it) } + ".json"))

    @Synchronized fun current(original: DownloadRequest): DownloadRequest = history(original).last()

    @Synchronized fun history(original: DownloadRequest): List<DownloadRequest> {
        val file = file(original.id)
        val document = try {
            JSONObject(file.openRead().bufferedReader().use { it.readText() })
        } catch (_: java.io.FileNotFoundException) { return listOf(original) }
        catch (error: Exception) { throw IOException("The download recovery checkpoint could not be read.", error) }
        // An explicitly replaced job must never inherit another job's checkpoint.
        if (document.optString("originalNamespace") != namespace(original)) return listOf(original)
        val requests = document.getJSONArray("requests")
        return listOf(original) + (0 until requests.length()).map { decode(original.id, requests.getJSONObject(it)) }
    }

    @Synchronized fun save(original: DownloadRequest, replacement: DownloadRequest) {
        val previous = history(original).drop(1)
        write(original, previous + replacement)
    }

    @Synchronized fun compact(original: DownloadRequest, current: DownloadRequest) {
        write(original, listOf(current))
    }

    private fun write(original: DownloadRequest, requests: List<DownloadRequest>) {
        val document = JSONObject().apply {
            put("originalNamespace", namespace(original))
            put("requests", JSONArray(requests.map(::encode)))
        }
        check(directory.isDirectory || directory.mkdirs()) { "Could not create the download recovery directory." }
        val file = file(original.id)
        val output = file.startWrite()
        try {
            output.write(document.toString().toByteArray(Charsets.UTF_8))
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw IOException("Could not save the renewed download.", error)
        }
    }

    @Synchronized fun delete(id: String) = file(id).delete()

    private fun encode(request: DownloadRequest): JSONObject = JSONObject().apply {
        put("uri", request.uri.toString())
        put("mimeType", request.mimeType)
        put("streamKeys", JSONArray(request.streamKeys.map { listOf(it.periodIndex, it.groupIndex, it.streamIndex) }))
        put("metadata", StreamDownloadStore.requestMetadata(request))
    }

    private fun decode(id: String, json: JSONObject): DownloadRequest {
        val keys = json.getJSONArray("streamKeys")
        return DownloadRequest.Builder(id, Uri.parse(json.getString("uri")))
            .setMimeType(json.getString("mimeType"))
            .setStreamKeys((0 until keys.length()).map { i ->
                val key = keys.getJSONArray(i)
                StreamKey(key.getInt(0), key.getInt(1), key.getInt(2))
            })
            .setData(json.getJSONObject("metadata").toString().toByteArray(Charsets.UTF_8)).build()
    }

    companion object {
        fun namespace(request: DownloadRequest): String = StreamDownloadStore.requestMetadata(request).optString("cacheNamespace")
        fun newNamespace(): String = "fq:${UUID.randomUUID()}:"
    }
}

/** The task stays alive during recovery, including when Flutter/the activity is closed. */
@UnstableApi
internal class RecoveringDownloader(
    private val original: DownloadRequest,
    private val state: DownloadRecoveryState,
    private val create: (DownloadRequest, List<DownloadRequest>) -> Downloader,
    private val refresh: (DownloadRequest, () -> Boolean) -> DownloadRequest,
    private val clearCache: (DownloadRequest) -> Unit,
) : Downloader {
    @Volatile private var cancelled = false
    @Volatile private var delegate: Downloader? = null
    private var attempts = 0
    private var recoveryFailure: IOException? = null

    override fun download(progressListener: Downloader.ProgressListener?) {
        recoveryFailure?.let { throw it }
        while (true) {
            checkCancelled()
            val history = state.history(original)
            val current = history.last()
            val next = create(current, history.dropLast(1))
            delegate = next
            checkCancelled()
            try {
                next.download(progressListener)
                if (history.size > 1) {
                    synchronized(this) {
                        checkCancelled()
                        try {
                            state.compact(original, current)
                            history.dropLast(1).forEach(clearCache)
                        } catch (_: IOException) {
                            // Cleanup must not fail a completed, readable download.
                        }
                    }
                }
                return
            } catch (error: IOException) {
                checkCancelled()
                if (!DownloadExpiry.isExpired(error) ||
                    StreamDownloadStore.requestMetadata(current).optJSONObject("source") == null) throw error
                if (++attempts > 2) {
                    fail(IOException("The renewed download link has expired again. Retry later.", error))
                }
                try {
                    val replacement = refresh(current) { cancelled || Thread.currentThread().isInterrupted }
                    synchronized(this) {
                        checkCancelled()
                        state.save(original, replacement)
                    }
                } catch (interrupted: InterruptedException) {
                    throw interrupted
                } catch (failure: Exception) {
                    fail(IOException(failure.message ?: "Could not renew this download. Retry later.", failure))
                }
            }
        }
    }

    private fun fail(error: IOException): Nothing {
        // Media3 retries IOExceptions on this instance. Do not repeatedly scrape a failed renewal.
        recoveryFailure = error
        throw error
    }

    private fun checkCancelled() {
        if (cancelled || Thread.currentThread().isInterrupted) throw InterruptedException("Download cancelled")
    }

    @Synchronized override fun cancel() {
        cancelled = true
        delegate?.cancel()
    }

    override fun remove() {
        // A damaged checkpoint must not make the download impossible to remove.
        val history = runCatching { state.history(original) }.getOrDefault(listOf(original))
        if (DownloadRecoveryState.namespace(original).isEmpty()) {
            create(original, emptyList()).remove()
        } else {
            history.forEach(clearCache)
        }
        state.delete(original.id)
    }
}
