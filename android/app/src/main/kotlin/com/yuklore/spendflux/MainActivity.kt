package com.yuklore.spendflux

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Store the application context so FluxAiHostApiImpl can access it
        // for MediaPipe session creation (which requires a Context).
        FluxAiHostApiImpl.appContext = applicationContext

        // Register the Pigeon host so Dart can call into the native LLM layer.
        FluxAiHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            FluxAiHostApiImpl(flutterEngine),
        )
    }
}
