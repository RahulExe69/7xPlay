package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.net.Uri
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.hls.offline.HlsDownloader
import androidx.media3.exoplayer.offline.DownloadRequest
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/** Real HTTP, Media3 HLS/cache and native resolver against the checked-in Postman simulation. */
@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
class DownloadRecoveryHttpTest {
    private fun base(): String {
        val base = System.getenv("FQ_DOWNLOAD_SIMULATION_URL")
        assumeTrue("Run the documented Postman simulation for HTTP coverage", !base.isNullOrBlank())
        return base!!
    }
    private fun request(base: String, id: Int = 42, episode: Boolean = false): DownloadRequest {
        val metadata = JSONObject().apply {
            put("title", "Fixture"); put("mediaType", if (episode) "episode" else "movie")
            put("contentId", id); put("seasonNumber", 0); put("episodeNumber", 2)
            put("format", "hls"); put("quality", "720p · original-server"); put("maxVideoHeight", 720)
            put("audioTrack", JSONObject().put("language", "hi")); put("selectedTracks", JSONArray())
            put("cacheNamespace", "original:")
            put("source", JSONObject().apply {
                put("version", 1); put("providerId", "original"); put("providerName", "Original")
                put("apiBaseUrl", base); put("server", "original-server"); put("quality", "720p")
            })
        }
        return DownloadRequest.Builder("movie_$id", Uri.parse("$base/old.m3u8"))
            .setMimeType(MimeTypes.APPLICATION_M3U8).setData(metadata.toString().toByteArray()).build()
    }
    @Test fun movieAndTvRegenerationPreserveOriginalSourceAndTrackConstraints() {
        val base = base()
        for (episode in listOf(false, true)) {
            val args = DownloadSourceResolver().resolve(request(base, episode = episode))
            assertEquals("$base/fresh.m3u8", args["url"])
            assertEquals("720p · original-server", args["quality"])
            assertEquals(720, args["maxVideoHeight"])
            assertEquals(mapOf("language" to "hi"), args["audioTrack"])
            assertEquals(mapOf("X-Stream-Generation" to "fresh"), args["headers"])
            assertEquals("original", (args["source"] as Map<*, *>)["providerId"])
        }
    }
    @Test fun refusesWrongProviderServerResolutionFormatAndAmbiguousSources() {
        val base = base()
        for (id in listOf(43, 44, 45, 46, 47, 48, 50)) {
            assertTrue("tmdbId $id must fail safely", runCatching { DownloadSourceResolver().resolve(request(base, id)) }.exceptionOrNull() is IOException)
        }
        assertEquals("$base/fresh.m3u8", DownloadSourceResolver().resolve(request(base, 49))["url"])
    }
    @Test fun changedUnverifiablePartialAndCorruptSegmentsAreFetchedAgain() {
        val base = base()
        val directory = Files.createTempDirectory("fq-cache-validation").toFile()
        val cache = SimpleCache(directory.resolve("cache"), NoOpCacheEvictor(),
            StandaloneDatabaseProvider(RuntimeEnvironment.getApplication()))
        try {
            for (mode in listOf("same", "changed", "noetag", "weak", "length", "corrupt", "partial")) {
                val url = "$base/one.ts?mode=$mode"
                val oldNamespace = "$mode-old:"
                val newNamespace = "$mode-new:"
                var newNetworkBytes = 0L
                fun factory(namespace: String, fresh: Boolean): CacheDataSource.Factory {
                    val http = DefaultHttpDataSource.Factory().setDefaultRequestProperties(
                        if (fresh) mapOf("X-Stream-Generation" to "fresh") else emptyMap())
                    val measured = DataSource.Factory {
                        val source = http.createDataSource()
                        object : DataSource by source {
                            override fun getResponseHeaders(): Map<String, List<String>> = source.responseHeaders
                            override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                                val count = source.read(buffer, offset, length)
                                if (fresh && count > 0) newNetworkBytes += count
                                return count
                            }
                        }
                    }
                    return CacheDataSource.Factory().setCache(cache)
                        .setCacheKeyFactory(DownloadCacheReuse.keyFactory(namespace))
                        .setUpstreamDataSourceFactory(DownloadCacheReuse.upstream(cache, namespace,
                            if (fresh) listOf(oldNamespace) else emptyList(), measured))
                }
                fun read(factory: CacheDataSource.Factory, partial: Boolean = false): String {
                    val source = factory.createDataSource()
                    val output = java.io.ByteArrayOutputStream()
                    try {
                        source.open(DataSpec(Uri.parse(url)))
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = source.read(buffer, 0, if (partial) 10 else buffer.size)
                            if (count == -1) break
                            output.write(buffer, 0, count)
                            if (partial) break
                        }
                    } finally { source.close() }
                    return output.toString("UTF-8")
                }
                val oldBytes = read(factory(oldNamespace, false), mode == "partial")
                if (mode == "corrupt") {
                    val span = cache.getCachedSpans(oldNamespace + url).first()
                    java.io.RandomAccessFile(span.file, "rw").use { it.writeByte(0) }
                }
                val fresh = read(factory(newNamespace, true))
                if (mode == "same") {
                    assertEquals(oldBytes, fresh)
                    assertEquals(0L, newNetworkBytes)
                } else {
                    assertTrue("$mode must fetch verified replacement bytes", newNetworkBytes > 0)
                    assertTrue(fresh.startsWith(if (mode == "changed") "modified-segment-one" else "verified-segment-one"))
                }
            }
        } finally { cache.release(); directory.deleteRecursively() }
    }
    @Test fun expiredSegmentRenewsOnceReusesVerifiedMediaAndRemainsReadableOffline() {
        val base = base()
        val context = RuntimeEnvironment.getApplication()
        val directory = Files.createTempDirectory("fq-download-http").toFile()
        val cache = SimpleCache(directory.resolve("cache"), NoOpCacheEvictor(), StandaloneDatabaseProvider(context))
        val state = DownloadRecoveryState(directory.resolve("recovery"))
        val original = request(base)
        val bytes = ConcurrentHashMap<String, AtomicLong>()
        var renewals = 0
        fun factory(request: DownloadRequest, previous: List<DownloadRequest>): CacheDataSource.Factory {
            val namespace = DownloadRecoveryState.namespace(request)
            val http = DefaultHttpDataSource.Factory().setDefaultRequestProperties(StreamDownloadStore.metadataHeaders(StreamDownloadStore.requestMetadata(request)))
            val measured = DataSource.Factory {
                val source = http.createDataSource()
                object : DataSource by source {
                    private var key = ""
                    override fun getResponseHeaders(): Map<String, List<String>> = source.responseHeaders
                    override fun open(dataSpec: DataSpec): Long {
                        key = namespace + dataSpec.uri.toString()
                        return source.open(dataSpec)
                    }
                    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                        val count = source.read(buffer, offset, length)
                        if (count > 0) bytes.getOrPut(key) { AtomicLong() }.addAndGet(count.toLong())
                        return count
                    }
                }
            }
            return CacheDataSource.Factory().setCache(cache).setCacheKeyFactory(DownloadCacheReuse.keyFactory(namespace))
                .setUpstreamDataSourceFactory(DownloadCacheReuse.upstream(cache, namespace, previous.map(DownloadRecoveryState::namespace), measured))
        }
        try {
            RecoveringDownloader(original, state,
                { current, previous -> HlsDownloader(current.toMediaItem(), factory(current, previous), Runnable::run) },
                { current, _ ->
                    renewals++
                    val args = DownloadSourceResolver().resolve(current)
                    val metadata = StreamDownloadStore.requestMetadata(current).apply {
                        put("headers", JSONObject(args["headers"] as Map<*, *>)); put("cacheNamespace", "renewed:")
                    }
                    DownloadRequest.Builder(current.id, Uri.parse(args["url"] as String)).setMimeType(current.mimeType)
                        .setStreamKeys(current.streamKeys).setData(metadata.toString().toByteArray()).build()
                },
                { old -> cache.keys.filter { it.startsWith(DownloadRecoveryState.namespace(old)) }.forEach(cache::removeResource) },
            ).download(null)
            assertEquals(1, renewals)
            assertTrue(bytes["original:$base/one.ts"]!!.get() > 0)
            assertEquals("Unchanged media must reuse local bytes", 0L, bytes["renewed:$base/one.ts"]?.get() ?: 0L)
            assertTrue(bytes["renewed:$base/two.ts"]!!.get() > 0)
            assertTrue(cache.keys.none { it.startsWith("original:") })
            val current = DownloadRecoveryState(directory.resolve("recovery")).current(original)
            assertEquals("$base/fresh.m3u8", current.uri.toString())
            val offline = CacheDataSource.Factory().setCache(cache).setUpstreamDataSourceFactory(null)
                .setCacheWriteDataSinkFactory(null).setCacheKeyFactory(DownloadCacheReuse.keyFactory("renewed:"))
            for (path in listOf("fresh.m3u8", "one.ts", "two.ts")) {
                val source = offline.createDataSource()
                try {
                    source.open(DataSpec(Uri.parse("$base/$path")))
                    val buffer = ByteArray(8192)
                    var count = 0L
                    while (true) {
                        val read = source.read(buffer, 0, buffer.size)
                        if (read == -1) break
                        count += read
                    }
                    assertTrue(count > 0)
                } finally { source.close() }
            }
        } finally { cache.release(); directory.deleteRecursively() }
    }
}
