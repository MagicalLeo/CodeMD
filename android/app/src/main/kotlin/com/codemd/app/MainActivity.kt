package com.codemd.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "codemd/intent"
    private var pendingUri: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> {
                    val path = handleUri(pendingUri)
                    pendingUri = null
                    result.success(path)
                }
                "cacheContentUri" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr != null) {
                        result.success(cacheContentUri(Uri.parse(uriStr)))
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingUri = intent?.data
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingUri = intent.data
        // Notify Flutter to fetch the new file path
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, channelName).invokeMethod("onNewFile", null)
        }
    }

    private fun handleUri(uri: Uri?): String? {
        if (uri == null) return null
        return when (uri.scheme) {
            "file" -> uri.path
            "content" -> cacheContentUri(uri)
            else -> uri.path
        }
    }

    private fun cacheContentUri(uri: Uri): String? {
        return try {
          val input = contentResolver.openInputStream(uri) ?: return null
          val tmpDir = File(cacheDir, "imports")
          if (!tmpDir.exists()) tmpDir.mkdirs()
          val fileName = uri.lastPathSegment?.substringAfterLast('/') ?: "import.md"
          val outFile = File(tmpDir, fileName)
          FileOutputStream(outFile).use { output ->
              input.copyTo(output)
          }
          outFile.absolutePath
        } catch (e: Exception) {
          null
        }
    }
}
