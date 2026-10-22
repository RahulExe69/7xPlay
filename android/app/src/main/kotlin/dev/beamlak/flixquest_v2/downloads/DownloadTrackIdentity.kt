package dev.beamlak.flixquest_v2.downloads

import androidx.media3.common.C
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.DownloadHelper
import org.json.JSONArray
import org.json.JSONObject

/** Rebuild stream keys from track identity; manifest indexes are not stable across signed URLs. */
@UnstableApi
internal object DownloadTrackIdentity {
    private fun identity(group: Tracks.Group, index: Int): JSONObject {
        val format = group.getTrackFormat(index)
        return JSONObject().apply {
            put("type", group.type)
            put("groupId", group.mediaTrackGroup.id)
            put("formatId", format.id ?: JSONObject.NULL)
            put("height", format.height)
            put("width", format.width)
            put("codecs", format.codecs ?: JSONObject.NULL)
            put("sampleMimeType", format.sampleMimeType ?: JSONObject.NULL)
            put("frameRate", format.frameRate.toDouble())
            put("language", format.language ?: JSONObject.NULL)
            put("label", format.label ?: JSONObject.NULL)
            put("roleFlags", format.roleFlags)
            put("channelCount", format.channelCount)
            put("sampleRate", format.sampleRate)
        }
    }

    fun capture(helper: DownloadHelper): JSONArray = JSONArray().apply {
        for (period in 0 until helper.periodCount) {
            val selected = JSONArray()
            helper.getTracks(period).groups.forEach { group ->
                if (group.type == C.TRACK_TYPE_VIDEO || group.type == C.TRACK_TYPE_AUDIO) {
                    for (index in 0 until group.length) {
                        if (group.isTrackSelected(index)) selected.put(identity(group, index))
                    }
                }
            }
            check((0 until selected.length()).any { selected.getJSONObject(it).getInt("type") == C.TRACK_TYPE_VIDEO }) {
                "The download's video track could not be identified."
            }
            put(selected)
        }
    }

    fun restore(helper: DownloadHelper, expected: JSONArray, parameters: androidx.media3.common.TrackSelectionParameters) {
        check(expected.length() == helper.periodCount) { "The original download's periods have changed." }
        for (period in 0 until helper.periodCount) {
            val selected = expected.getJSONArray(period)
            val builder = parameters.buildUpon()
            for (i in 0 until selected.length()) {
                val saved = selected.getJSONObject(i)
                val type = saved.getInt("type")
                val candidates = helper.getTracks(period).groups.filter { it.type == type }.flatMap { group ->
                    (0 until group.length).filter { group.isTrackSupported(it) }.map { group to it }
                }
                fun matches(candidate: Pair<Tracks.Group, Int>, keys: List<String>): Boolean {
                    val actual = identity(candidate.first, candidate.second)
                    return keys.all {
                        val a = actual.opt(it)
                        val b = saved.opt(it)
                        if (a is Number && b is Number) a.toDouble() == b.toDouble() else a == b
                    }
                }
                val semantic = listOf("type", "height", "width", "codecs", "sampleMimeType", "frameRate", "language", "label", "roleFlags", "channelCount", "sampleRate")
                val exact = candidates.filter { matches(it, semantic + listOf("groupId", "formatId")) }
                val descriptive = type == C.TRACK_TYPE_VIDEO && saved.optInt("height") > 0 ||
                    !saved.isNull("language") || !saved.isNull("label")
                val matching = if (exact.isNotEmpty()) exact else if (descriptive) candidates.filter { matches(it, semantic) } else emptyList()
                // Different group IDs with identical descriptions can be different dubs.
                check(matching.map { it.first.mediaTrackGroup.id }.distinct().size == 1) {
                    "The original video or audio track is unavailable or ambiguous."
                }
                val match = matching.maxBy { it.first.getTrackFormat(it.second).bitrate }
                builder.setOverrideForType(TrackSelectionOverride(match.first.mediaTrackGroup, listOf(match.second)))
            }
            helper.replaceTrackSelections(period, builder.build())
        }
        check(capture(helper).toString() == expected.toString() || sameSelections(capture(helper), expected)) {
            "The original download tracks could not be selected."
        }
    }

    private fun sameSelections(actual: JSONArray, expected: JSONArray): Boolean {
        fun normalize(array: JSONArray): List<String> = (0 until array.length()).map { p ->
            val tracks = array.getJSONArray(p)
            (0 until tracks.length()).map { i ->
                JSONObject(tracks.getJSONObject(i).toString()).apply { remove("groupId"); remove("formatId") }.toString()
            }.sorted().joinToString()
        }
        return normalize(actual) == normalize(expected)
    }
}
