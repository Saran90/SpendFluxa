import 'dart:async';

import '../engine/abstract_ai_engine.dart';

/// Test double for [AbstractAiEngine].
///
/// Provides controllable broadcast streams so unit and widget tests can
/// simulate token emission, completion, and errors without a real model.
///
/// Usage:
/// ```dart
/// final mock = MockAiEngine();
/// await mock.loadModel('any_path');
///
/// mock.emitTokens(['Hello', ' world']);
/// mock.emitCompletion('Hello world');
/// ```
class MockAiEngine implements AbstractAiEngine {
  bool _loaded = false;

  final _tokenCtrl = StreamController<String>.broadcast();
  final _completeCtrl = StreamController<String>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  // ── AbstractAiEngine ──────────────────────────────────────────────────────

  @override
  bool get isModelLoaded => _loaded;

  @override
  Stream<String> get tokenStream => _tokenCtrl.stream;

  @override
  Stream<String> get completeStream => _completeCtrl.stream;

  @override
  Stream<String> get errorStream => _errorCtrl.stream;

  @override
  Future<bool> loadModel(String path) async {
    _loaded = true;
    return true;
  }

  @override
  Future<void> unloadModel() async {
    _loaded = false;
  }

  @override
  Future<bool> generateResponseStreaming(
    String prompt,
    String systemPrompt,
  ) async {
    // Default behaviour: echo the prompt as a single token + completion.
    // Tests can override behaviour by calling [emitTokens] / [emitCompletion]
    // after calling [generateResponseStreaming] if they need custom sequences.
    _tokenCtrl.add(prompt);
    _completeCtrl.add(prompt);
    return true;
  }

  @override
  Future<String> generateResponse(String prompt, String systemPrompt) async {
    // Default: return the prompt unchanged (useful for summarisation tests).
    return prompt;
  }

  @override
  void cancelGeneration() {
    // No-op in mock; tests may inspect call counts if needed.
  }

  @override
  void dispose() {
    if (!_tokenCtrl.isClosed) _tokenCtrl.close();
    if (!_completeCtrl.isClosed) _completeCtrl.close();
    if (!_errorCtrl.isClosed) _errorCtrl.close();
  }

  // ── Test helpers ──────────────────────────────────────────────────────────

  /// Emits each string in [tokens] onto the token stream in order.
  void emitTokens(List<String> tokens) {
    for (final t in tokens) {
      if (!_tokenCtrl.isClosed) _tokenCtrl.add(t);
    }
  }

  /// Emits [response] onto the completion stream.
  void emitCompletion(String response) {
    if (!_completeCtrl.isClosed) _completeCtrl.add(response);
  }

  /// Emits [message] onto the error stream.
  void emitError(String message) {
    if (!_errorCtrl.isClosed) _errorCtrl.add(message);
  }
}
