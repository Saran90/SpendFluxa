import 'dart:async';
import 'dart:io';

import '../pigeon/flux_ai_api.g.dart';

/// Dart wrapper around Pigeon Flux AI host API.
class FluxAiEngine implements FluxAiFlutterApi {
  FluxAiEngine() {
    FluxAiFlutterApi.setUp(this);
    _host = FluxAiHostApi();
  }

  late final FluxAiHostApi _host;

  final _tokenController = StreamController<String>.broadcast();
  final _completeController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get tokenStream => _tokenController.stream;
  Stream<String> get completeStream => _completeController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool _modelLoaded = false;
  bool get isModelLoaded => _modelLoaded;

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

  Future<bool> loadModel(String modelPath) async {
    if (!Platform.isAndroid) {
      _modelLoaded = false;
      return false;
    }
    final file = File(modelPath);
    if (!await file.exists()) {
      _modelLoaded = false;
      return false;
    }
    try {
      final ok = await _host.loadModel(modelPath);
      _modelLoaded = ok;
      return ok;
    } catch (e) {
      _modelLoaded = false;
      onGenerationError('Model load failed: $e');
      return false;
    }
  }

  Future<void> unloadModel() async {
    if (!Platform.isAndroid) return;
    try {
      await _host.unloadModel();
    } catch (_) {}
    _modelLoaded = false;
  }

  Future<FluxAiModelStatus> getModelStatus() async {
    if (!Platform.isAndroid) {
      return FluxAiModelStatus(
        isLoaded: false,
        modelPath: null,
        errorMessage: 'Flux AI is only available on Android',
      );
    }
    return _host.getModelStatus();
  }

  Future<String> generateResponse(String prompt, String systemPrompt) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Flux AI requires Android');
    }
    return _host.generateResponse(prompt, systemPrompt);
  }

  Future<bool> generateResponseStreaming(
    String prompt,
    String systemPrompt,
  ) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Flux AI requires Android');
    }
    return _host.generateResponseStreaming(prompt, systemPrompt);
  }

  void cancelGeneration() {
    if (!Platform.isAndroid) return;
    _host.cancelGeneration();
  }

  void dispose() {
    cancelGeneration();
    _tokenController.close();
    _completeController.close();
    _errorController.close();
  }
}
