package dev.beamlak.flixquest_v2.downloads

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.CacheKeyFactory
import androidx.media3.datasource.cache.ContentMetadata
import androidx.media3.datasource.cache.ContentMetadataMutations
import androidx.media3.datasource.cache.SimpleCache
import java.io.IOException
import java.security.MessageDigest

/** Cache generations isolate changed manifests, track indexes, keys and byte ranges.
 * Only a complete, unchanged resource can cross generations; URLs/tokens are never stripped.
 */
@UnstableApi
internal object DownloadCacheReuse {
    private const val ETAG = "custom_fq_strong_etag"
    private const val LENGTH = "custom_fq_resource_length"
    private const val DIGEST = "custom_fq_sha256"

    fun keyFactory(namespace: String): CacheKeyFactory = CacheKeyFactory { spec ->
        val key = spec.key ?: spec.uri.toString()
        if (key.startsWith(namespace)) key else namespace + key
    }

    fun upstream(cache: SimpleCache, namespace: String, previous: List<String>, factory: DataSource.Factory): DataSource.Factory =
        DataSource.Factory { ValidatedDataSource(cache, namespace, previous, factory.createDataSource()) }

    private class ValidatedDataSource(
        private val cache: SimpleCache,
        private val namespace: String,
        private val previous: List<String>,
        private val network: DataSource,
    ) : DataSource {
        private var cached: DataSource? = null
        private var spec: DataSpec? = null
        private var digest: MessageDigest? = null
        private var expectedLength = -1L
        private var readLength = 0L
        private var currentKey: String? = null
        override fun addTransferListener(transferListener: TransferListener) = network.addTransferListener(transferListener)
        override fun getUri(): Uri? = spec?.uri
        override fun getResponseHeaders(): Map<String, List<String>> = network.responseHeaders

        override fun open(dataSpec: DataSpec): Long {
            spec = dataSpec
            try {
                val length = network.open(dataSpec)
                fun header(name: String) = network.responseHeaders.entries.firstOrNull { it.key.equals(name, true) }?.value?.firstOrNull()
                val type = header("Content-Type").orEmpty().lowercase()
                if (type.contains("text/html") || type.contains("application/json")) throw IOException("The stream returned an error document instead of media.")
                val etag = header("ETag")?.takeIf { it.startsWith('"') && it.endsWith('"') }
                // A range response's validator covers the whole resource, but its
                // length does not. Reuse only full resources and full responses.
                val reusable = etag != null && length > 0 && dataSpec.position == 0L &&
                    dataSpec.length == C.LENGTH_UNSET.toLong() && header("Content-Range") == null &&
                    !type.contains("mpegurl") && !type.contains("dash+xml") &&
                    dataSpec.uri.path?.let { !it.endsWith(".m3u8", true) && !it.endsWith(".mpd", true) } != false
                // CacheDataSource passes its already namespaced key upstream.
                val key = dataSpec.key ?: namespace + dataSpec.uri.toString()
                val resourceKey = key.removePrefix(namespace)
                currentKey = key
                if (reusable) {
                    val oldKey = previous.asReversed().map { it + resourceKey }.firstOrNull { candidate ->
                        val metadata = cache.getContentMetadata(candidate)
                        metadata.get(ETAG, "") == etag && metadata.get(LENGTH, -1L) == length &&
                            ContentMetadata.getContentLength(metadata) == length && cache.isCached(candidate, 0, length) &&
                            verified(candidate, dataSpec, metadata.get(DIGEST, "").orEmpty())
                    }
                    if (oldKey != null) {
                        // Copy through the normal cache writer. This keeps each job
                        // independently removable and offline playback entirely local.
                        cached = CacheDataSource.Factory().setCache(cache).setUpstreamDataSourceFactory(null)
                            .setCacheWriteDataSinkFactory(null).createDataSource().also {
                                it.open(dataSpec.buildUpon().setKey(oldKey).build())
                            }
                        network.close()
                    }
                    cache.applyContentMetadataMutations(key, ContentMetadataMutations().set(ETAG, etag!!).set(LENGTH, length))
                    digest = MessageDigest.getInstance("SHA-256")
                    expectedLength = length
                    readLength = 0
                }
                return length
            } catch (error: Exception) {
                close()
                throw error
            }
        }
        private fun verified(key: String, dataSpec: DataSpec, expected: String): Boolean {
            if (expected.isEmpty()) return false
            val input = CacheDataSource.Factory().setCache(cache).setUpstreamDataSourceFactory(null)
                .setCacheWriteDataSinkFactory(null).createDataSource()
            return try {
                input.open(dataSpec.buildUpon().setKey(key).build())
                val hash = MessageDigest.getInstance("SHA-256")
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    if (Thread.currentThread().isInterrupted) throw InterruptedException()
                    val count = input.read(buffer, 0, buffer.size)
                    if (count == C.RESULT_END_OF_INPUT) break
                    hash.update(buffer, 0, count)
                }
                hash.digest().hex() == expected
            } catch (_: IOException) { false } finally { input.close() }
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            val count = (cached ?: network).read(buffer, offset, length)
            val hash = digest
            if (count > 0 && hash != null) {
                hash.update(buffer, offset, count)
                readLength += count
                if (readLength == expectedLength) {
                    cache.applyContentMetadataMutations(checkNotNull(currentKey), ContentMetadataMutations().set(DIGEST, hash.digest().hex()))
                    digest = null
                }
            }
            return count
        }

        private fun ByteArray.hex() = joinToString("") { "%02x".format(it) }
        override fun close() {
            try { cached?.close() } finally {
                cached = null
                try { network.close() } finally { spec = null; digest = null; currentKey = null }
            }
        }
    }
}
