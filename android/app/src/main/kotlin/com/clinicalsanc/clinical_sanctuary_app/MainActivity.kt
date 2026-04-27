package com.clinicalsanc.clinical_sanctuary_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(M83VlcPlayerViewFactory.VIEW_TYPE, M83VlcPlayerViewFactory())

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            M83VlcPlayerViewFactory.CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "takeSnapshot" -> {
                    val viewId = call.argument<Int>("viewId")
                    if (viewId == null) {
                        result.error("missing_view_id", "Missing VLC view id.", null)
                        return@setMethodCallHandler
                    }
                    M83VlcPlayerRegistry.takeSnapshot(viewId, result)
                }
                else -> result.notImplemented()
            }
        }
    }
}
