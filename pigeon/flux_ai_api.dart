// ignore_for_file: one_member_abstracts
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/assistant/pigeon/flux_ai_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/yuklore/spendflux/FluxAiApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.yuklore.spendflux'),
  ),
)
/// Status data returned by [FluxAiHostApi.getModelStatus].
class FluxAiModelStatus {
  FluxAiModelStatus({
    required this.isLoaded,
    this.modelPath,
    this.errorMessage,
  });

  bool isLoaded;
  String? modelPath;
  String? errorMessage;
}

/// Result returned by [FluxAiHostApi.getAssetPackModelPath].
class AssetPackStatus {
  AssetPackStatus({
    required this.isAvailable,
    this.modelPath,
    this.errorMessage,
  });

  /// True when the asset pack is installed and the model file is accessible.
  bool isAvailable;

  /// Absolute path to the model file inside the asset pack, or null.
  String? modelPath;

  /// Human-readable error when [isAvailable] is false.
  String? errorMessage;
}

/// Dart → Android: host-side API for LLM inference operations.
@HostApi()
abstract class FluxAiHostApi {
  /// Returns the absolute path to the Gemma model inside the Play Asset
  /// Delivery pack ("model_delivery"), or an error message if the pack is not
  /// yet installed.
  @async
  AssetPackStatus getAssetPackModelPath();

  /// Loads the Gemma model from [modelPath]. Returns true on success.
  @async
  bool loadModel(String modelPath);

  /// Unloads the active model and releases native resources.
  @async
  void unloadModel();

  /// Returns the current model load status.
  @async
  FluxAiModelStatus getModelStatus();

  /// Generates a full (non-streaming) response synchronously.
  /// Prefer [generateResponseStreaming] for interactive chat.
  @async
  String generateResponse(String prompt, String systemPrompt);

  /// Begins streaming generation. Tokens arrive via [FluxAiFlutterApi.onToken].
  /// Returns true if generation was started successfully.
  @async
  bool generateResponseStreaming(String prompt, String systemPrompt);

  /// Cancels any in-progress generation immediately.
  void cancelGeneration();
}

/// Android → Dart: Flutter-side callbacks from the native LLM layer.
@FlutterApi()
abstract class FluxAiFlutterApi {
  /// Called for each token emitted during streaming generation.
  void onToken(String token);

  /// Called when streaming generation completes with the full response text.
  void onGenerationComplete(String fullResponse);

  /// Called when the native layer encounters an error during inference.
  void onGenerationError(String message);
}
