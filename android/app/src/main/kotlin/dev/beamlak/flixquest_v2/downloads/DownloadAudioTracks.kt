package dev.beamlak.flixquest_v2.downloads

import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import java.util.Locale

/** Keep track identity as well as language: a language may have multiple dubs/commentaries. */
@UnstableApi
internal object DownloadAudioTracks {
    private data class Candidate(val group: Tracks.Group, val index: Int) {
        val format: Format get() = group.getTrackFormat(index)
        val identity: Map<String, Any?> get() = mapOf(
            "groupId" to group.mediaTrackGroup.id,
            "formatId" to format.id,
            "language" to format.language,
            "label" to format.label,
            "roleFlags" to format.roleFlags,
            "channelCount" to format.channelCount,
            "sampleMimeType" to format.sampleMimeType,
        )
    }

    private fun candidates(tracks: Tracks): List<Candidate> = buildList {
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO) continue
            for (index in 0 until group.length) {
                if (group.isTrackSupported(index)) add(Candidate(group, index))
            }
        }
    }

    fun choices(tracks: Tracks): List<Map<String, Any?>> {
        // Bitrate variants of the same rendition are one choice. Retain the best
        // supported format; the exact format is selected again when enqueueing.
        val choices = candidates(tracks)
            .groupBy { it.identity - "formatId" }
            .values.map { formats -> formats.maxBy { it.format.bitrate } }
        val names = choices.mapIndexed { index, candidate ->
            val format = candidate.format
            val language = format.language?.takeUnless { it == "und" }
                ?.let { Locale.forLanguageTag(it).getDisplayLanguage(Locale.getDefault()) }
                ?.takeIf { it.isNotBlank() }
            val label = format.label?.takeIf { it.isNotBlank() }
            val name = listOfNotNull(language, label)
                .distinctBy { it.lowercase(Locale.ROOT) }.joinToString(" · ")
                .ifBlank { "Audio ${index + 1}" }
            if (format.channelCount > 2) "$name · ${format.channelCount} ch" else name
        }
        return choices.mapIndexed { index, candidate ->
            mapOf(
                "name" to if (names.count { it == names[index] } > 1) {
                    "${names[index]} (${index + 1})"
                } else names[index],
                "selection" to candidate.identity,
            )
        }
    }

    fun findOverride(tracks: Tracks, selection: Map<*, *>): TrackSelectionOverride? {
        val available = candidates(tracks)
        val exact = available.firstOrNull { it.identity == selection }
        // DASH periods can change adaptation/representation IDs. Match the same
        // language, label, role and audio format in that case, never another dub.
        val semanticKeys = listOf("language", "label", "roleFlags", "channelCount", "sampleMimeType")
        val hasDescription = selection["language"] != null || selection["label"] != null
        val match = exact ?: if (hasDescription) {
            available.filter { candidate ->
                semanticKeys.all { candidate.identity[it] == selection[it] }
            }.maxByOrNull { it.format.bitrate }
        } else null
        return match?.let { TrackSelectionOverride(it.group.mediaTrackGroup, listOf(it.index)) }
    }
}
