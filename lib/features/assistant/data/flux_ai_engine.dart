import 'dart:async';
import 'dart:io';

import '../engine/abstract_ai_engine.dart';
import '../pigeon/flux_ai_api.g.dart';

/// Concrete [AbstractAiEngine] implementation backed by MediaPipe LLM
/// Inference via the Pigeon-generated [FluxAiHostApi] / [FluxAiFlutterApi].
///
/// Android-only: all methods return safe no-op values on other platforms.
class FluxAiEngine implements AbstractAiEngine, FluxAiFlutterApi {
  FluxAiEngine() {
    // Register this instance as the Dart-side Pigeon callback receiver.
    FluxAiFlutterApi.setUp(this);
    _host = FluxAiHostApi();
  }

  late final FluxAiHostApi _host;

  final _tokenController = StreamController<String>.broadcast();
  final _completeController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _modelLoaded = false;

  // ── AbstractAiEngine ──────────────────────────────────────────────────────

  @override
  bool get isModelLoaded => _modelLoaded;

  @override
  Stream<String> get tokenStream => _tokenController.stream;

  @override
  Stream<String> get completeStream => _completeController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Future<bool> loadModel(String path) async {
    if (!Platform.isAndroid) {
      _modelLoaded = false;
      return false;
    }
    final file = File(path);
    if (!await file.exists()) {
      _modelLoaded = false;
      _errorController.add('Model file not found: $path');
      return false;
    }
    try {
      final ok = await _host.loadModel(path);
      _modelLoaded = ok;
      return ok;
    } catch (e) {
      _modelLoaded = false;
      _errorController.add('Model load failed: $e');
      return false;
    }
  }

  @override
  Future<void> unloadModel() async {
    if (!Platform.isAndroid) return;
    try {
      await _host.unloadModel();
    } catch (_) {}
    _modelLoaded = false;
  }

  @override
  Future<bool> generateResponseStreaming(
    String prompt,
    String systemPrompt,
  ) async {
    if (!Platform.isAndroid) {
      _errorController.add('Flux AI is only available on Android.');
      return false;
    }
    try {
      return await _host.generateResponseStreaming(prompt, systemPrompt);
    } catch (e) {
      _errorController.add('Generation failed: $e');
      return false;
    }
  }

  @override
  Future<String> generateResponse(String prompt, String systemPrompt) async {
    if (!Platform.isAndroid) {
      return '';
    }
    try {
      return await _host.generateResponse(prompt, systemPrompt);
    } catch (e) {
      _errorController.add('Generation failed: $e');
      return '';
    }
  }

  @override
  void cancelGeneration() {
    if (!Platform.isAndroid) return;
    try {
      _host.cancelGeneration();
    } catch (_) {}
  }

  @override
  void dispose() {
    cancelGeneration();
    if (!_tokenController.isClosed) _tokenController.close();
    if (!_completeController.isClosed) _completeController.close();
    if (!_errorController.isClosed) _errorController.close();
  }

  // ── FluxAiFlutterApi callbacks (called from native Android layer) ─────────

  @override
  void onToken(String token) {
    if (!_tokenController.isClosed) {
      _tokenController.add(token);
    }
  }

  @override
  void onGenerationComplete(String fullResponse) {
    if (!_completeController.isClosed) {
      _completeController.add(fullResponse);
    }
  }

  @override
  void onGenerationError(String message) {
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the current model status from the native layer.
  /// Useful for diagnostics; not part of [AbstractAiEngine].
  Future<FluxAiModelStatus> getModelStatus() async {
    if (!Platform.isAndroid) {
      return FluxAiModelStatus(
        isLoaded: false,
        modelPath: null,
        errorMessage: 'Flux AI is only available on Android.',
      );
    }
    return _host.getModelStatus();
  }
}
