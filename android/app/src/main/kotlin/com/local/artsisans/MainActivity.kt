package com.local.artsisans

import android.graphics.BitmapFactory
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
	private val CHANNEL = "com.local.artsisans/gemini"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"describeImageWithNano" -> {
					val base64Image = call.argument<String>("imageBase64")
					if (base64Image == null) {
						result.error("NO_IMAGE", "No image provided", null)
					} else {
						describeImage(base64Image, result)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun describeImage(base64Image: String, result: MethodChannel.Result) {
		try {
			val bytes = Base64.decode(base64Image, Base64.DEFAULT)
			val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

			// Temporary fallback: simple heuristic suggestion without ML Kit,
			// so the app compiles and runs on all devices. You can replace this
			// block with the official ML Kit GenAI Image Description API when
			// available on your target devices/SDK.
			val width = bitmap?.width ?: 0
			val height = bitmap?.height ?: 0
			val aspect = if (height > 0) width.toFloat() / height.toFloat() else 1f
			val baseSuggestion = StringBuilder().apply {
				append("Refine composition, enhance details, and reduce noise. ")
				append("Apply gentle contrast and natural color balance. ")
				if (aspect > 1.3f) append("Landscape emphasis; add depth and clarity.")
				else if (aspect < 0.8f) append("Portrait emphasis; soften background, keep subject crisp.")
				else append("Square-ish framing; center subject and add subtle vignette.")
			}
			result.success(baseSuggestion.toString())
		} catch (e: Exception) {
			result.error("EXCEPTION", e.message, null)
		}
	}
}
