package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.TrackGroup
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.hls.playlist.HlsMultivariantPlaylist
import androidx.media3.exoplayer.hls.playlist.HlsPlaylistParser
import com.google.common.collect.ImmutableList
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
class DownloadAudioTracksTest {
    @Test fun hlsMasterExposesHindiAndOverridesEnglishDefault() {
        val manifest = """
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,URI="english.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Hindi",LANGUAGE="hi",DEFAULT=NO,AUTOSELECT=YES,URI="hindi.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1280x720,AUDIO="audio"
            video.m3u8
        """.trimIndent()
        val playlist = HlsPlaylistParser().parse(
            Uri.parse("https://example.test/master.m3u8"), manifest.byteInputStream(),
        ) as HlsMultivariantPlaylist
        val groups = playlist.audios.map { TrackGroup(it.name, it.format) }
        val tracks = tracks(*groups.toTypedArray())
        val choices = DownloadAudioTracks.choices(tracks)
        assertEquals(2, choices.size)
        assertTrue(choices[1]["name"].toString().contains("Hindi"))
        val override = DownloadAudioTracks.findOverride(tracks, selection(choices[1]))!!
        assertEquals("hi", override.mediaTrackGroup.getFormat(override.trackIndices.single()).language)
        assertNotEquals(groups[0], override.mediaTrackGroup)
    }

    @Test fun bitrateVariantsAreOneChoiceUsingHighestSupportedBitrate() {
        val group = TrackGroup("hi", audio("hi-low", "hi", bitrate = 64000), audio("hi-high", "hi", bitrate = 128000))
        val tracks = tracks(group)
        val choices = DownloadAudioTracks.choices(tracks)
        assertEquals(1, choices.size)
        assertEquals(listOf(1), DownloadAudioTracks.findOverride(tracks, selection(choices.single()))!!.trackIndices)
    }

    @Test fun separateHindiDubsAndCommentaryRemainSeparateChoices() {
        val tracks = tracks(
            TrackGroup("main", audio("hi-main", "hi", label = "Original")),
            TrackGroup("dub", audio("hi-dub", "hi", label = "Dubbed")),
            TrackGroup("commentary", audio("hi-commentary", "hi", role = C.ROLE_FLAG_COMMENTARY)),
        )
        val choices = DownloadAudioTracks.choices(tracks)
        assertEquals(3, choices.size)
        assertEquals("dub", DownloadAudioTracks.findOverride(tracks, selection(choices[1]))!!.mediaTrackGroup.id)
    }

    @Test fun dashPeriodCanChangeIdsWithoutChangingSelectedLanguage() {
        val first = tracks(TrackGroup("period1", audio("p1-hi", "hi")))
        val next = tracks(
            TrackGroup("period2-en", audio("p2-en", "en")),
            TrackGroup("period2-hi", audio("p2-hi", "hi")),
        )
        val selection = selection(DownloadAudioTracks.choices(first).single())
        assertEquals("period2-hi", DownloadAudioTracks.findOverride(next, selection)!!.mediaTrackGroup.id)
    }

    @Test fun missingSelectedDubNeverFallsBackToEnglishOrCommentary() {
        val first = tracks(TrackGroup("hi", audio("hi", "hi")))
        val next = tracks(
            TrackGroup("en", audio("en", "en")),
            TrackGroup("commentary", audio("hi-commentary", "hi", role = C.ROLE_FLAG_COMMENTARY)),
        )
        assertNull(DownloadAudioTracks.findOverride(next, selection(DownloadAudioTracks.choices(first).single())))
    }

    @Test fun unsupportedAudioAndVideoAreNotOfferedAsAudioChoices() {
        val hindi = TrackGroup("hi", audio("hi", "hi"))
        val unsupported = Tracks.Group(hindi, false, intArrayOf(C.FORMAT_UNSUPPORTED_TYPE), booleanArrayOf(false))
        val video = TrackGroup("video", Format.Builder().setSampleMimeType(MimeTypes.VIDEO_H264).build())
        assertTrue(DownloadAudioTracks.choices(Tracks(ImmutableList.of(unsupported, tracks(video).groups.single()))).isEmpty())
    }

    @Test fun unnamedTracksHaveDistinctNamesAndCannotMatchUnrelatedIds() {
        val first = tracks(TrackGroup("one", audio("one", null)), TrackGroup("two", audio("two", null)))
        val choices = DownloadAudioTracks.choices(first)
        assertEquals(listOf("Audio 1", "Audio 2"), choices.map { it["name"] })
        val next = tracks(TrackGroup("three", audio("three", null)))
        assertNull(DownloadAudioTracks.findOverride(next, selection(choices.first())))
    }

    private fun selection(choice: Map<String, Any?>) = choice["selection"] as Map<*, *>

    private fun tracks(vararg groups: TrackGroup) = Tracks(ImmutableList.copyOf(groups.map { group ->
        Tracks.Group(group, false, IntArray(group.length) { C.FORMAT_HANDLED }, BooleanArray(group.length))
    }))

    private fun audio(id: String, language: String?, bitrate: Int = 128000, label: String? = null, role: Int = 0): Format =
        Format.Builder().setId(id).setLanguage(language).setLabel(label)
            .setSampleMimeType(MimeTypes.AUDIO_AAC).setChannelCount(2)
            .setAverageBitrate(bitrate).setRoleFlags(role).build()
}
