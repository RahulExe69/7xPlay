package dev.beamlak.flixquest_v2.downloads

import android.net.Uri
import android.util.Base64
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.offline.DownloadRequest
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Refresh only positively identified expiry, never connectivity errors or generic HTTP failures. */
@UnstableApi
internal object DownloadExpiry {
    fun isExpired(error: IOException): Boolean {
        val response = generateSequence<Throwable>(error) { it.cause }
            .filterIsInstance<HttpDataSource.InvalidResponseCodeException>().firstOrNull() ?: return false
        if (response.responseCode !in listOf(400, 401, 403, 404, 410)) return false
        val body = response.responseBody.toString(Charsets.UTF_8).take(4096).lowercase()
        if (Regex("\\bexpired\\b|\\btoken_expired\\b|\\bexpiredtoken\\b|\\brequestexpired\\b").containsMatchIn(body) &&
            !Regex("\\bnot\\s+expired\\b").containsMatchIn(body)) return true
        if (response.responseCode !in listOf(401, 403, 410)) return false
        val uri = response.dataSpec.uri
        val now = System.currentTimeMillis() / 1000
        for (name in listOf("expires", "Expires", "exp")) {
            val expires = uri.getQueryParameter(name)?.toLongOrNull() ?: continue
            if (expires in 1..now) return true
        }
        // A JWT's expiry is only a hint after the server has rejected this URL.
        val token = uri.getQueryParameter("token") ?: return false
        return try {
            val parts = token.split('.')
            if (parts.size != 3) false else {
                val payload = JSONObject(String(Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_WRAP)))
                payload.optLong("exp", Long.MAX_VALUE) in 1..now
            }
        } catch (_: Exception) { false }
    }
}

@UnstableApi
internal class DownloadSourceResolver {
    /** Returns preparation arguments retaining the original source and track constraints. */
    fun resolve(request: DownloadRequest): Map<String, Any?> {
        val metadata = StreamDownloadStore.requestMetadata(request)
        val source = metadata.optJSONObject("source") ?: throw IOException("Download source metadata is unavailable.")
        checkSource(source, metadata)
        val query = buildMap {
            put("provider", source.getString("providerId"))
            put("tmdbId", metadata.getInt("contentId").toString())
            if (metadata.getString("mediaType") == "episode") {
                put("season", metadata.getInt("seasonNumber").toString())
                put("episode", metadata.getInt("episodeNumber").toString())
            }
        }
        val path = if (metadata.getString("mediaType") == "movie") "/stream-movie" else "/stream-tv"
        val base = source.getString("apiBaseUrl").trim().trimEnd('/')
            .let { if (it.endsWith("/api/v2")) it else "$it/api/v2" }
        fun fetch(full: Boolean): JSONObject {
            val uri = Uri.parse("$base$path").buildUpon()
            query.forEach { (key, value) -> uri.appendQueryParameter(key, value) }
            if (full) uri.appendQueryParameter("full", "true")
            return getJson(uri.build().toString())
        }
        var body = fetch(true)
        if (!body.optBoolean("success") && body.optString("error").contains("full stream collection", true)) {
            body = fetch(false)
        }
        if (!body.optBoolean("success") || body.optString("provider") != source.getString("providerId")) {
            throw IOException("Could not renew the original download provider. Retry later.")
        }
        body.optJSONObject("media")?.let { media ->
            val expectedType = if (metadata.getString("mediaType") == "movie") "movie" else "show"
            if (media.optString("tmdbId") != metadata.getInt("contentId").toString() || media.optString("type") != expectedType) {
                throw IOException("The renewed source does not match the original title.")
            }
        }
        val format = metadata.getString("format")
        val links = body.optJSONArray("links") ?: throw IOException("The original download source is unavailable.")
        val matches = (0 until links.length()).mapNotNull { links.optJSONObject(it) }.filter { link ->
            val streamUrl = link.optString("url")
            val streamPath = runCatching { Uri.parse(streamUrl).path.orEmpty().lowercase() }
                .getOrDefault("")
            val progressive = listOf(".mp4", ".m4v", ".mov", ".webm", ".mkv", ".avi", ".mpg", ".mpeg", ".flv", ".wmv")
                .any { extension -> streamPath.endsWith(extension) }
            val linkFormat = when {
                progressive -> "progressive"
                link.optBoolean("isM3U8") || streamPath.endsWith(".m3u8") -> "hls"
                link.optBoolean("isDASH") || streamPath.endsWith(".mpd") -> "dash"
                else -> "hls"
            }
            link.optString("quality", "unknown quality") == source.getString("quality") &&
                link.optString("server") == source.optString("server") &&
                linkFormat == format &&
                streamUrl.isNotBlank()
        }.distinctBy { jsonMap(it) }
        if (matches.size != 1) {
            throw IOException("The original server and quality are unavailable or ambiguous. Retry later.")
        }
        val link = matches.single()
        val uri = Uri.parse(link.getString("url"))
        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrBlank()) throw IOException("Invalid renewed download URL.")
        val headers = link.optJSONObject("headers")?.let(::jsonMap)?.takeIf { it.isNotEmpty() }
            ?: if (uri.host?.let { it == "vixsrc.to" || it.endsWith(".vixsrc.to") } == true) {
                mapOf("accept" to "*/*", "origin" to "https://vixsrc.to", "referer" to "https://vixsrc.to/",
                    "user-agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36")
            } else emptyMap()
        return jsonMap(metadata) + mapOf(
            "id" to request.id,
            "url" to uri.toString(),
            "headers" to headers,
        )
    }

    private fun checkSource(source: JSONObject, metadata: JSONObject) {
        if (source.optInt("version") != 1 || source.optString("providerId").isBlank() ||
            source.optString("quality").isBlank() || metadata.optInt("contentId") <= 0 ||
            metadata.optString("cacheNamespace").isBlank() ||
            metadata.optJSONArray("selectedTracks") == null ||
            metadata.optString("format") !in listOf("hls", "dash", "progressive") ||
            metadata.optString("mediaType") !in listOf("movie", "episode")) {
            throw IOException("Download recovery metadata is incomplete.")
        }
        val base = Uri.parse(source.optString("apiBaseUrl"))
        if (base.scheme !in listOf("http", "https") || base.host.isNullOrBlank()) throw IOException("Invalid download API URL.")
        if (metadata.optString("mediaType") == "episode" &&
            (metadata.optInt("seasonNumber", -1) < 0 || metadata.optInt("episodeNumber", -1) <= 0)) {
            throw IOException("Download episode metadata is incomplete.")
        }
    }

    private fun getJson(url: String): JSONObject {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 10_000
        connection.readTimeout = 60_000
        connection.setRequestProperty("Accept", "application/json")
        try {
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            val body = try { JSONObject(text) } catch (_: Exception) { throw IOException("Download provider returned an invalid response (HTTP $code).") }
            if (code !in 200..299 && !body.optString("error").contains("full stream collection", true)) {
                throw IOException("Download provider is unavailable (HTTP $code). Retry later.")
            }
            return body
        } finally { connection.disconnect() }
    }

    companion object {
        private fun jsonValue(value: Any?): Any? = when (value) {
            null, JSONObject.NULL -> null
            is JSONObject -> jsonMap(value)
            is org.json.JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
            else -> value
        }

        fun jsonMap(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith { key -> jsonValue(json.get(key)) }
    }
}
