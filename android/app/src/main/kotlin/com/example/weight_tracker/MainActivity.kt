package com.example.weight_tracker

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "saveCsv" -> {
                        val fileName = call.argument<String>("fileName")
                        val content = call.argument<String>("content")
                        if (fileName.isNullOrBlank() || content == null) {
                            result.error("BAD_ARGS", "fileName and content are required", null)
                            return@setMethodCallHandler
                        }
                        // Run I/O off the platform thread; reply on the main thread.
                        Thread {
                            try {
                                val saved = saveCsv(fileName, content)
                                runOnUiThread { result.success(saved) }
                            } catch (e: SecurityException) {
                                runOnUiThread { result.error("PERMISSION", e.message, null) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("IO", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveCsv(fileName: String, content: String): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(fileName, content)
        } else {
            saveLegacy(fileName, content)
        }

    /** Android 10+: MediaStore Downloads collection, no permission needed. */
    @RequiresApi(Build.VERSION_CODES.Q)
    private fun saveWithMediaStore(fileName: String, content: String): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("Could not create the file in Downloads")
        try {
            resolver.openOutputStream(uri)?.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                ?: throw IOException("Could not open the file for writing")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // MediaStore may rename on conflict; report the actual name.
        resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) return c.getString(0) }
        return fileName
    }

    /** Android 9 and below: public Downloads directory (needs WRITE_EXTERNAL_STORAGE). */
    @Suppress("DEPRECATION")
    private fun saveLegacy(fileName: String, content: String): String {
        if (Environment.getExternalStorageState() != Environment.MEDIA_MOUNTED) {
            throw IOException("External storage is not available")
        }
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("Could not create the Downloads folder")
        }
        val file = File(dir, fileName)
        file.writeText(content, Charsets.UTF_8)
        return file.name
    }

    companion object {
        private const val CHANNEL = "weight_tracker/downloads"
    }
}
