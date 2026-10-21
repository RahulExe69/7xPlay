package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.net.Uri
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.StreamKey
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.ByteArrayDataSource
import androidx.media3.datasource.DataSource
import androidx.media3.exoplayer.BaseRenderer
import androidx.media3.exoplayer.RendererCapabilities
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.offline.DownloadHelper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.io.IOException

/** Exercise Media3's real manifest preparation, selector and persisted download stream keys. */
@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
@LooperMode(LooperMode.Mode.PAUSED)
class DownloadAudioStreamKeysTest {
    @Test fun hindiOverrideDownloadsOnlyHindiAndPreserves720pVideo() {
        val manifest = """
            <MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" mediaPresentationDuration="PT10S" minBufferTime="PT1S">
              <Period duration="PT10S">
                <AdaptationSet id="0" contentType="video" mimeType="video/mp4" codecs="avc1.640028">
                  <Representation id="v480" bandwidth="500000" width="854" height="480"><BaseURL>480.mp4</BaseURL></Representation>
                  <Representation id="v720" bandwidth="1500000" width="1280" height="720"><BaseURL>720.mp4</BaseURL></Representation>
                  <Representation id="v1080" bandwidth="3000000" width="1920" height="1080"><BaseURL>1080.mp4</BaseURL></Representation>
                </AdaptationSet>
                <AdaptationSet id="1" contentType="audio" mimeType="audio/mp4" codecs="mp4a.40.2" lang="en">
                  <Representation id="en" bandwidth="128000" audioSamplingRate="48000"><BaseURL>en.mp4</BaseURL></Representation>
                </AdaptationSet>
                <AdaptationSet id="2" contentType="audio" mimeType="audio/mp4" codecs="mp4a.40.2" lang="hi">
                  <Representation id="hi" bandwidth="128000" audioSamplingRate="48000"><BaseURL>hi.mp4</BaseURL></Representation>
                </AdaptationSet>
              </Period>
            </MPD>
        """.trimIndent()
        val source = DashMediaSource.Factory(DataSource.Factory { ByteArrayDataSource(manifest.toByteArray()) })
            .createMediaSource(MediaItem.fromUri(Uri.parse("https://example.test/video.mpd")))
        val parameters = TrackSelectionParameters.Builder()
            .setPreferredAudioLanguage("en")
            .setMaxVideoSize(Int.MAX_VALUE, 720)
            .setForceHighestSupportedBitrate(true).build()
        val helper = DownloadHelper.Factory()
            .setRenderersFactory(RenderersFactory { _, _, _, _, _ ->
                arrayOf(SupportedRenderer(C.TRACK_TYPE_VIDEO), SupportedRenderer(C.TRACK_TYPE_AUDIO))
            })
            .setTrackSelectionParameters(parameters)
            .create(source)
        var prepared = false
        var error: IOException? = null
        helper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper, tracksInfoAvailable: Boolean) {
                prepared = tracksInfoAvailable
            }
            override fun onPrepareError(helper: DownloadHelper, failure: IOException) { error = failure }
        })
        try {
            val deadline = System.nanoTime() + 5_000_000_000L
            while (!prepared && error == null && System.nanoTime() < deadline) {
                shadowOf(Looper.getMainLooper()).idle()
                Thread.sleep(10)
            }
            assertNull(error)
            assertTrue("Manifest preparation completed", prepared)
            assertEquals(listOf(StreamKey(0, 0, 1), StreamKey(0, 1, 0)), helper.getDownloadRequest(null).streamKeys)
            val hindi = DownloadAudioTracks.choices(helper.getTracks(0)).single {
                (it["selection"] as Map<*, *>)["language"] == "hi"
            }
            val override = DownloadAudioTracks.findOverride(helper.getTracks(0), hindi["selection"] as Map<*, *>)!!
            helper.replaceTrackSelections(0, parameters.buildUpon().setOverrideForType(override).build())
            assertEquals(listOf(StreamKey(0, 0, 1), StreamKey(0, 2, 0)), helper.getDownloadRequest(null).streamKeys)
            // Serialize exactly as a persisted request does (JSON normalizes numeric types).
            val originalTracks = org.json.JSONArray(DownloadTrackIdentity.capture(helper).toString())
            val changedDefaults = parameters.buildUpon().setMaxVideoSize(Int.MAX_VALUE, 1080).build()
            helper.replaceTrackSelections(0, changedDefaults)
            DownloadTrackIdentity.restore(helper, originalTracks, changedDefaults)
            assertEquals(listOf(StreamKey(0, 0, 1), StreamKey(0, 2, 0)), helper.getDownloadRequest(null).streamKeys)
            val englishBlock = Regex("<AdaptationSet id=\"1\".*?</AdaptationSet>", RegexOption.DOT_MATCHES_ALL).find(manifest)!!.value
            val hindiBlock = Regex("<AdaptationSet id=\"2\".*?</AdaptationSet>", RegexOption.DOT_MATCHES_ALL).find(manifest)!!.value
            val reordered = manifest.replace(englishBlock, "ENGLISH_PLACEHOLDER")
                .replace(hindiBlock, englishBlock).replace("ENGLISH_PLACEHOLDER", hindiBlock)
                .replace("id=\"v720\"", "id=\"renewed-v720\"")
            val refreshed = DownloadHelper.Factory()
                .setRenderersFactory(RenderersFactory { _, _, _, _, _ ->
                    arrayOf(SupportedRenderer(C.TRACK_TYPE_VIDEO), SupportedRenderer(C.TRACK_TYPE_AUDIO))
                }).setTrackSelectionParameters(changedDefaults)
                .create(DashMediaSource.Factory(DataSource.Factory { ByteArrayDataSource(reordered.toByteArray()) })
                    .createMediaSource(MediaItem.fromUri("https://example.test/renewed.mpd")))
            var refreshedReady = false
            var refreshedError: IOException? = null
            refreshed.prepare(object : DownloadHelper.Callback {
                override fun onPrepared(helper: DownloadHelper, tracksInfoAvailable: Boolean) { refreshedReady = tracksInfoAvailable }
                override fun onPrepareError(helper: DownloadHelper, error: IOException) { refreshedError = error }
            })
            try {
                val refreshedDeadline = System.nanoTime() + 5_000_000_000L
                while (!refreshedReady && refreshedError == null && System.nanoTime() < refreshedDeadline) {
                    shadowOf(Looper.getMainLooper()).idle()
                    Thread.sleep(10)
                }
                assertNull(refreshedError)
                assertTrue(refreshedReady)
                DownloadTrackIdentity.restore(refreshed, originalTracks, changedDefaults)
                assertEquals(listOf(StreamKey(0, 0, 1), StreamKey(0, 1, 0)), refreshed.getDownloadRequest(null).streamKeys)
            } finally { refreshed.release() }
            val missingQuality = org.json.JSONArray(originalTracks.toString())
            val savedVideo = missingQuality.getJSONArray(0).getJSONObject(0)
            savedVideo.put("height", 2160)
            assertTrue(runCatching { DownloadTrackIdentity.restore(helper, missingQuality, parameters) }.exceptionOrNull() is IllegalStateException)
        } finally {
            helper.release()
        }
    }

    /** Codec boundary only: the real Media3 manifest and track-selection code runs above. */
    private class SupportedRenderer(type: Int) : BaseRenderer(type) {
        override fun getName() = "SupportedRenderer"
        override fun supportsFormat(format: Format) = RendererCapabilities.create(
            if (MimeTypes.getTrackType(format.sampleMimeType) == trackType) C.FORMAT_HANDLED else C.FORMAT_UNSUPPORTED_TYPE,
        )
        override fun render(positionUs: Long, elapsedRealtimeUs: Long) {}
        override fun isReady() = true
        override fun isEnded() = false
    }
}
