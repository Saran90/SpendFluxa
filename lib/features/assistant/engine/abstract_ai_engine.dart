/// Abstract interface for the on-device LLM inference backend.
///
/// All chat orchestration code depends only on this interface.
/// The concrete implementation ([FluxAiEngine]) uses MediaPipe + Pigeon.
/// A [MockAiEngine] is provided for unit and widget tests.
abstract class AbstractAiEngine {
  /// Whether the model is currently loaded and ready for inference.
  bool get isModelLoaded;

  /// Emits individual tokens during streaming generation.
  Stream<String> get tokenStream;

  /// Emits the complete response text when streaming finishes.
  Stream<String> get completeStream;

  /// Emits error messages from the native inference layer.
  Stream<String> get errorStream;

  /// Loads the model from [path]. Returns `true` on success, `false` otherwise.
  /// On non-Android platforms this always returns `false`.
  Future<bool> loadModel(String path);

  /// Unloads the active model and releases all native resources.
  Future<void> unloadModel();

  /// Begins streaming generation for [prompt] with [systemPrompt].
  ///
  /// Returns immediately; tokens arrive via [tokenStream].
  /// The full response is emitted on [completeStream] when done.
  /// Any errors are emitted on [errorStream].
  Future<bool> generateResponseStreaming(String prompt, String systemPrompt);

  /// Generates a complete (non-streaming) response.
  ///
  /// Used internally for context summarisation — not for interactive chat.
  Future<String> generateResponse(String prompt, String systemPrompt);

  /// Cancels any in-progress generation.
  void cancelGeneration();

  /// Releases stream controllers. Call when the engine is no longer needed.
  void dispose();
}
