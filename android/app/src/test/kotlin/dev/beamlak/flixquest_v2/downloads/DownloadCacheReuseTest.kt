package dev.beamlak.flixquest_v2.downloads

import android.app.Application
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.ByteArrayDataSource
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.nio.file.Files

/** Hosts label TS segments text/html or hide them in images; downloads must still cache plain TS. */
@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
class DownloadCacheReuseTest {
    private val segment = ByteArray(188 * 8) { i -> if (i % 188 == 0) 0x47 else (i * 31).toByte() }

    private fun read(body: ByteArray, contentType: String, mimeType: String? = null): ByteArray {
        val directory = Files.createTempDirectory("fq-error-document").toFile()
        val cache = SimpleCache(directory.resolve("cache"), NoOpCacheEvictor(),
            StandaloneDatabaseProvider(RuntimeEnvironment.getApplication()))
        val network = StreamDownloadStore.mediaFactory(mimeType) {
            val source = ByteArrayDataSource(body)
            object : DataSource by source {
                override fun getResponseHeaders(): Map<String, List<String>> = mapOf("Content-Type" to listOf(contentType))
            }
        }
        val source = DownloadCacheReuse.upstream(cache, "test:", emptyList(), network).createDataSource()
        try {
            source.open(DataSpec(Uri.parse("https://cdn.test/segment")))
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(100)
            while (true) {
                val count = source.read(buffer, 0, buffer.size)
                if (count == C.RESULT_END_OF_INPUT) break
                output.write(buffer, 0, count)
            }
            return output.toByteArray()
        } finally { source.close(); cache.release(); directory.deleteRecursively() }
    }

    @Test fun transportStreamLabelledHtmlIsReadIntact() {
        assertArrayEquals(segment, read(segment, "text/html; charset=UTF-8"))
        assertArrayEquals(segment, read(segment, "text/html; charset=UTF-8", MimeTypes.APPLICATION_M3U8))
    }

    @Test fun hlsSegmentHiddenInAnImageIsCachedAsPlainTs() {
        // A 1x1 PNG with the TS appended after IEND, as the player's unwrapper expects.
        val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) +
            byteArrayOf(0, 0, 0, 13) + "IHDR".toByteArray() + byteArrayOf(0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0) + ByteArray(4) +
            byteArrayOf(0, 0, 0, 0) + "IEND".toByteArray() + ByteArray(4)
        val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte()) + ByteArray(40) + "TIKTIKRAW".toByteArray()
        for ((wrapper, type) in listOf(png to "image/png", png to "text/html", jpeg to "image/jpeg")) {
            assertArrayEquals("$type", segment, read(wrapper + segment, type, MimeTypes.APPLICATION_M3U8))
        }
    }

    @Test fun shortBinaryKeyLabelledJsonIsReadIntact() {
        val key = byteArrayOf(0x7B, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F)
        assertArrayEquals(key, read(key, "application/json"))
    }

    @Test fun errorDocumentsAreRejected() {
        for ((body, type) in listOf(
            "﻿  <!DOCTYPE html><html><body>403 Forbidden</body></html>" to "text/html",
            "{\"error\":\"token expired\"}" to "application/json; charset=utf-8",
        )) {
            val error = runCatching { read(body.toByteArray(), type) }.exceptionOrNull()
            assertTrue("'$body' must be rejected", error is IOException && error.message!!.contains("error document"))
        }
    }
}
