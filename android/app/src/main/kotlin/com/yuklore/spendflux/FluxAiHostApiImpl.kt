package com.yuklore.spendflux

import android.os.Handler
import android.os.Looper
import com.google.android.play.core.assetpacks.AssetPackManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInference.LlmInferenceOptions
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File

private const val PACK_NAME = "model_delivery"
private const val MODEL_FILE_NAME = "gemma3-1b-it-int4.task"
private const val MODEL_FILE = "model/$MODEL_FILE_NAME"

/**
 * Implements [FluxAiHostApi] by delegating LLM inference to the
 * MediaPipe LLM Inference API (on-device, no network required).
 *
 * Lifecycle:
 *  - [loadModel]  → creates an [LlmInference] session (GPU if available, CPU fallback).
 *  - [generateResponseStreaming] → runs async inference; tokens are forwarded to
 *    Dart via [FluxAiFlutterApi.onToken] and [FluxAiFlutterApi.onGenerationComplete].
 *  - [unloadModel] → closes the session and releases all native resources.
 */
class FluxAiHostApiImpl(
    private val flutterEngine: FlutterEngine,
) : FluxAiHostApi {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var llmInference: LlmInference? = null
    private var loadedModelPath: String? = null
    private var assetPackManager: AssetPackManager? = null

    @Volatile
    private var isCancelled = false

    // ── FluxAiHostApi ─────────────────────────────────────────────────────────

    /**
     * Resolves the absolute path of the Gemma model from the Play Asset
     * Delivery pack. For install-time packs, the pack is always available
     * after installation, so this will succeed immediately.
     *
     * On first call, initialises the [AssetPackManager] using the stored
     * application context.
     */
    override fun getAssetPackModelPath(callback: (Result<AssetPackStatus>) -> Unit) {
        val ctx = appContext ?: run {
            callback(Result.success(AssetPackStatus(
                isAvailable = false,
                modelPath = null,
                errorMessage = "Application context not available.",
            )))
            return
        }

        val manager = assetPackManager
            ?: AssetPackManagerFactory.getInstance(ctx).also { assetPackManager = it }

        val location = manager.getPackLocation(PACK_NAME)
        if (location == null) {
            // Pack not yet installed — expected during local `flutter run` development.
            // Fall back to a manually pushed model at a well-known dev path so the AI
            // feature can be tested without a full Play bundle.
            val devPath = "/data/local/tmp/llm/$MODEL_FILE_NAME"
            val devFile = File(devPath)

            // Also check app-private files dir (always accessible to the app).
            val appFilesPath = "${ctx.filesDir.absolutePath}/$MODEL_FILE_NAME"
            val appFilesModel = File(appFilesPath)

            val resolvedPath: String? = when {
                devFile.exists() -> devPath
                appFilesModel.exists() -> appFilesPath
                else -> null
            }

            if (resolvedPath != null) {
                callback(Result.success(AssetPackStatus(
                    isAvailable = true,
                    modelPath = resolvedPath,
                    errorMessage = null,
                )))
            } else {
                callback(Result.success(AssetPackStatus(
                    isAvailable = false,
                    modelPath = null,
                    errorMessage = "Asset pack '$PACK_NAME' is not installed and the " +
                        "local dev model was not found.\n" +
                        "Push the model via adb to test locally:\n" +
                        "  adb shell mkdir -p /data/local/tmp/llm/\n" +
                        "  adb push gemma3-1b-it-int4.task /data/local/tmp/llm/",
                )))
            }
            return
        }

        val modelPath = "${location.assetsPath()}/$MODEL_FILE"
        val exists = File(modelPath).exists()
        callback(Result.success(AssetPackStatus(
            isAvailable = exists,
            modelPath = if (exists) modelPath else null,
            errorMessage = if (!exists) "Model file not found in asset pack at: $modelPath" else null,
        )))
    }

    override fun loadModel(modelPath: String, callback: (Result<Boolean>) -> Unit) {
        scope.launch {
            try {
                // Close any existing session before loading a new one.
                llmInference?.close()
                llmInference = null
                loadedModelPath = null

                val options = LlmInferenceOptions.builder()
                    .setModelPath(modelPath)
                    .setMaxTokens(4096)
                    .setMaxTopK(40)
                    .build()

                llmInference = LlmInference.createFromOptions(
                    flutterEngine.dartExecutor.binaryMessenger.let {
                        // We need a Context; pull it from the FlutterEngine's activity.
                        // FlutterEngine itself carries an ApplicationContext via its
                        // FlutterJNI instance — use the application context stored in the
                        // companion object set during configureFlutterEngine.
                        appContext!!
                    },
                    options,
                )
                loadedModelPath = modelPath
                mainHandler.post { callback(Result.success(true)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    override fun unloadModel(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            try {
                llmInference?.close()
                llmInference = null
                loadedModelPath = null
                mainHandler.post { callback(Result.success(Unit)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    override fun getModelStatus(callback: (Result<FluxAiModelStatus>) -> Unit) {
        val status = FluxAiModelStatus(
            isLoaded = llmInference != null,
            modelPath = loadedModelPath,
            errorMessage = null,
        )
        callback(Result.success(status))
    }

    override fun generateResponse(
        prompt: String,
        systemPrompt: String,
        callback: (Result<String>) -> Unit,
    ) {
        val llm = llmInference
        if (llm == null) {
            callback(Result.failure(IllegalStateException("Model is not loaded.")))
            return
        }
        scope.launch {
            try {
                val fullPrompt = buildPrompt(systemPrompt, prompt)
                val result = llm.generateResponse(fullPrompt)
                mainHandler.post { callback(Result.success(result)) }
            } catch (e: Exception) {
                mainHandler.post { callback(Result.failure(e)) }
            }
        }
    }

    override fun generateResponseStreaming(
        prompt: String,
        systemPrompt: String,
        callback: (Result<Boolean>) -> Unit,
    ) {
        val llm = llmInference
        if (llm == null) {
            callback(Result.failure(IllegalStateException("Model is not loaded.")))
            return
        }

        isCancelled = false
        val flutterApi = FluxAiFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        val fullPrompt = buildPrompt(systemPrompt, prompt)
        val responseBuilder = StringBuilder()

        scope.launch {
            try {
                llm.generateResponseAsync(fullPrompt) { partialResult, done ->
                    if (isCancelled) return@generateResponseAsync

                    if (partialResult != null) {
                        responseBuilder.append(partialResult)
                        mainHandler.post {
                            flutterApi.onToken(partialResult) { /* ignore callback errors */ }
                        }
                    }

                    if (done) {
                        val full = responseBuilder.toString()
                        mainHandler.post {
                            flutterApi.onGenerationComplete(full) { }
                        }
                    }
                }
                // Signal to Dart that streaming has been initiated.
                mainHandler.post { callback(Result.success(true)) }
            } catch (e: Exception) {
                val msg = e.message ?: "Unknown inference error"
                mainHandler.post {
                    flutterApi.onGenerationError(msg) { }
                    callback(Result.failure(e))
                }
            }
        }
    }

    override fun cancelGeneration() {
        isCancelled = true
        // MediaPipe does not expose a direct cancel API on LlmInference;
        // we set the flag so the progress listener ignores further tokens.
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Combines [systemPrompt] and [userPrompt] into the format expected
     * by the Gemma instruction-tuned model.
     *
     * Gemma IT format:
     *   <start_of_turn>user
     *   {system}\n\n{user}<end_of_turn>
     *   <start_of_turn>model
     */
    private fun buildPrompt(systemPrompt: String, userPrompt: String): String {
        return "<start_of_turn>user\n$systemPrompt\n\n$userPrompt<end_of_turn>\n<start_of_turn>model\n"
    }

    companion object {
        /** Application context set once during [MainActivity.configureFlutterEngine]. */
        var appContext: android.content.Context? = null
    }
}
