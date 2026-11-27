package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.net.Uri
import androidx.media3.common.MimeTypes
import androidx.media3.common.StreamKey
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.Downloader
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.IOException
import java.nio.file.Files

@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
class DownloadRecoveryTest {
    private fun request(namespace: String = "old:", source: Boolean = true, key: Int = 0): DownloadRequest =
        DownloadRequest.Builder("movie_42", Uri.parse("https://example.test/$namespace/master.m3u8"))
            .setMimeType(MimeTypes.APPLICATION_M3U8).setStreamKeys(listOf(StreamKey(0, 0, key)))
            .setData(JSONObject().apply {
                put("cacheNamespace", namespace)
                if (source) put("source", JSONObject().put("version", 1))
            }.toString().toByteArray()).build()

    private fun response(code: Int, body: String = "", url: String = "https://example.test/video"): IOException =
        HttpDataSource.InvalidResponseCodeException(code, "error", null, emptyMap(), DataSpec(Uri.parse(url)), body.toByteArray())

    private fun state() = DownloadRecoveryState(Files.createTempDirectory("fq-recovery").toFile().also { it.deleteOnExit() })
    private class Task(val operation: () -> Unit = {}) : Downloader {
        var cancelled = false
        override fun download(progressListener: Downloader.ProgressListener?) = operation()
        override fun cancel() { cancelled = true }
        override fun remove() {}
    }

    @Test fun providerHttpFailuresQualifyForFallbackButNetworkFailuresDoNot() {
        for (code in listOf(400, 401, 403, 404, 408, 410, 425, 429, 500, 502, 503, 504)) {
            assertTrue("HTTP $code should allow a provider fallback",
                DownloadSourceFailure.isRetryable(response(code, "Unavailable")))
        }
        for (code in listOf(200, 301, 304, 416)) {
            assertFalse("HTTP $code should not rotate providers",
                DownloadSourceFailure.isRetryable(response(code, "Not a fallback status")))
        }
        assertFalse(DownloadSourceFailure.isRetryable(java.net.SocketTimeoutException()))
        assertFalse(DownloadSourceFailure.isRetryable(java.net.UnknownHostException()))
        assertTrue(DownloadSourceFailure.isRetryable(
            java.net.SocketTimeoutException(), networkValidated = true))
        assertTrue(DownloadSourceFailure.isRetryable(
            java.net.UnknownHostException(), networkValidated = true))
        assertFalse(DownloadSourceFailure.isRetryable(
            IOException("disk full"), networkValidated = true))
    }

    @Test fun temporaryProviderFailuresAdvanceThroughCandidatesInOrder() {
        val original = request("original:")
        val second = request("second:")
        val third = request("third:")
        val attempted = mutableListOf<String>()
        RecoveringDownloader(
            original,
            state(),
            { current, _ ->
                Task {
                    attempted.add(current.uri.toString())
                    if (current.uri.toString().contains("original:") ||
                        current.uri.toString().contains("second:")) {
                        throw response(503, "Provider temporarily unavailable")
                    }
                }
            },
            { _, _ -> fail("A temporary HTTP failure should use the next candidate") },
            {},
            fallback = { current, _ ->
                when {
                    current.uri.toString().contains("original:") -> second
                    current.uri.toString().contains("second:") -> third
                    else -> null
                }
            },
        ).download(null)

        assertEquals(
            listOf(
                original.uri.toString(),
                second.uri.toString(),
                third.uri.toString(),
            ),
            attempted,
        )
    }

    @Test fun rankedFallbackArgumentsKeepAudioAndAdvanceTheRemainingCandidates() {
        val directoryRequest = DownloadRequest.Builder(
            "movie_42",
            Uri.parse("https://example.test/original/master.m3u8"),
        ).setMimeType(MimeTypes.APPLICATION_M3U8)
            .setData(JSONObject().apply {
                put("title", "Fixture")
                put("mediaType", "movie")
                put("contentId", 42)
                put("format", "hls")
                put("quality", "1080p")
                put("cacheNamespace", "original:")
                put("audioTrack", JSONObject().put("language", "hi"))
                put("fallbackCandidates", JSONArray().apply {
                    put(JSONObject().apply {
                        put("url", "https://second.example/master.m3u8")
                        put("format", "hls")
                        put("quality", "1080p")
                        put("providerName", "Second")
                        put("headers", JSONObject().put("Referer", "https://second.example/"))
                        put("audioTrack", JSONObject().put("language", "hi").put("formatId", "hi-1"))
                        put("audioTrackName", "Hindi")
                    })
                    put(JSONObject().apply {
                        put("url", "https://third.example/master.m3u8")
                        put("format", "hls")
                        put("quality", "1080p")
                        put("providerName", "Third")
                    })
                })
            }.toString().toByteArray()).build()

        val resolver = DownloadSourceResolver()
        val first = resolver.nextFallbackArguments(directoryRequest)!!
        assertEquals("https://second.example/master.m3u8", first["url"])
        assertEquals("hls", first["format"])
        assertEquals("1080p", first["quality"])
        assertEquals("Hindi", first["audioTrackName"])
        assertEquals(mapOf("language" to "hi", "formatId" to "hi-1"), first["audioTrack"])
        assertEquals(mapOf("Referer" to "https://second.example/"), first["headers"])
        assertEquals(1, (first["fallbackCandidates"] as List<*>).size)
        assertNotEquals("original:", first["cacheNamespace"])

        val second = resolver.nextFallbackArguments(directoryRequest, 1)!!
        assertEquals("https://third.example/master.m3u8", second["url"])
        assertTrue((second["fallbackCandidates"] as List<*>).isEmpty())
    }

    @Test fun onlyPositiveExpiryEvidenceQualifies() {
        for (code in listOf(400, 401, 403, 404, 410)) assertTrue(DownloadExpiry.isExpired(response(code, "Token expired")))
        for (code in listOf(401, 403, 404, 410, 429, 500, 503)) assertFalse(DownloadExpiry.isExpired(response(code, "Forbidden")))
        assertFalse(DownloadExpiry.isExpired(response(503, "Token expired")))
        assertFalse(DownloadExpiry.isExpired(response(403, "Token is not expired")))
        assertFalse(DownloadExpiry.isExpired(java.net.SocketTimeoutException()))
        assertFalse(DownloadExpiry.isExpired(java.net.UnknownHostException()))
        assertTrue(DownloadExpiry.isExpired(response(403, url = "https://example.test/file?expires=1")))
        assertTrue(DownloadExpiry.isExpired(IOException(response(403, "ExpiredToken"))))
    }

    @Test fun renewedRequestAndNewStreamKeysSurviveRestartWithoutAnotherRefresh() {
        val original = request()
        val renewed = request("new:", key = 2)
        val state = state()
        var refreshes = 0
        val cleared = mutableListOf<String>()
        RecoveringDownloader(original, state, { current, _ -> Task {
            if (current == original) throw response(403, "Token expired")
        } }, { _, _ -> refreshes++; renewed }, { cleared.add(DownloadRecoveryState.namespace(it)) }).download(null)
        assertEquals(1, refreshes)
        assertEquals(renewed, state.current(original))
        assertEquals(listOf(StreamKey(0, 0, 2)), state.current(original).streamKeys)
        assertEquals(listOf("old:"), cleared)
        RecoveringDownloader(original, state, { current, _ -> assertEquals(renewed, current); Task() },
            { _, _ -> fail("A valid resumed link must not be regenerated"); renewed }, {}).download(null)
    }

    @Test fun ordinaryErrorsAndLegacyDownloadsNeverRegenerate() {
        for ((original, failure) in listOf(request() to response(503), request() to response(403, "Forbidden"),
            request(source = false) to response(403, "Token expired"))) {
            val downloader = RecoveringDownloader(original, state(), { _, _ -> Task { throw failure } },
                { _, _ -> fail("Unexpected regeneration"); original }, {})
            assertSame(failure, runCatching { downloader.download(null) }.exceptionOrNull())
        }
    }

    @Test fun failedRenewalIsNotRepeatedByMedia3AutomaticRetries() {
        var calls = 0
        val downloader = RecoveringDownloader(request(), state(), { _, _ -> Task { throw response(403, "Token expired") } },
            { _, _ -> calls++; throw IOException("Provider unavailable") }, {})
        repeat(5) { assertTrue(runCatching { downloader.download(null) }.exceptionOrNull() is IOException) }
        assertEquals(1, calls)
    }

    @Test fun exhaustedProviderFallbackIsTerminalAndDoesNotRepeatTheSameSource() {
        var attempts = 0
        val downloader = RecoveringDownloader(
            request(source = false),
            state(),
            { _, _ ->
                attempts++
                Task { throw response(503, "Provider unavailable") }
            },
            { _, _ -> fail("A non-expired provider failure must not renew the same source") },
            {},
            fallback = { _, _ -> null },
        )

        repeat(4) {
            assertTrue(runCatching { downloader.download(null) }.exceptionOrNull() is IOException)
        }
        assertEquals("The failed source must only be attempted once", 1, attempts)
    }

    @Test fun repeatedExpiredReplacementsAreBounded() {
        var calls = 0
        val downloader = RecoveringDownloader(request(), state(), { _, _ -> Task { throw response(403, "Token expired") } },
            { _, _ -> calls++; request("new$calls:") }, {})
        repeat(3) { assertTrue(runCatching { downloader.download(null) }.exceptionOrNull() is IOException) }
        assertEquals(2, calls)
    }

    @Test fun pauseDuringRenewalDoesNotCommitOrStartReplacement() {
        val original = request()
        val state = state()
        var started = 0
        lateinit var downloader: RecoveringDownloader
        downloader = RecoveringDownloader(original, state, { _, _ -> started++; Task { throw response(403, "Token expired") } },
            { _, _ -> downloader.cancel(); request("new:") }, {})
        assertTrue(runCatching { downloader.download(null) }.exceptionOrNull() is InterruptedException)
        assertEquals(original, state.current(original))
        assertEquals(1, started)
    }

    @Test fun removalClearsEveryGenerationAndItsCheckpoint() {
        val original = request()
        val state = state()
        state.save(original, request("second:"))
        state.save(original, request("third:"))
        val removed = mutableListOf<String>()
        RecoveringDownloader(original, state, { _, _ -> Task() }, { _, _ -> error("not used") },
            { removed.add(DownloadRecoveryState.namespace(it)) }).remove()
        assertEquals(listOf("old:", "second:", "third:"), removed)
        assertEquals(original, state.current(original))
    }

    @Test fun corruptCheckpointsFailSafelyButCanStillBeRemoved() {
        val directory = Files.createTempDirectory("fq-corrupt-checkpoint").toFile()
        try {
            val state = DownloadRecoveryState(directory)
            val original = request()
            state.save(original, request("new:"))
            directory.listFiles()!!.single().writeText("broken JSON")
            assertTrue(runCatching { state.current(original) }.exceptionOrNull() is IOException)
            val removed = mutableListOf<String>()
            RecoveringDownloader(original, state, { _, _ -> Task() }, { _, _ -> error("not used") },
                { removed.add(DownloadRecoveryState.namespace(it)) }).remove()
            assertEquals(listOf("old:"), removed)
            assertEquals(original, state.current(original))
        } finally { directory.deleteRecursively() }
    }

    @Test fun anUnrelatedReplacementJobNeverInheritsOldCheckpoint() {
        val state = state()
        state.save(request(), request("renewed:"))
        assertEquals(request("other:"), state.current(request("other:")))
    }
}
