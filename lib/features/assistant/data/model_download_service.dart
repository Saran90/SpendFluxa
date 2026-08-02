import 'dart:async';

import 'package:flutter/foundation.dart';

import 'model_storage.dart';

/// Progress snapshot emitted by [ModelDeliveryService.progressStream].
class DownloadProgress {
  const DownloadProgress({
    required this.bytesDownloaded,
    required this.totalBytes,
    this.isComplete = false,
    this.error,
  });

  final int bytesDownloaded;

  /// -1 when size is unknown.
  final int totalBytes;

  final bool isComplete;

  /// Non-null when an error occurred.
  final String? error;

  bool get hasError => error != null;

  /// 0.0–1.0, or -1.0 when total size is unknown.
  double get percentage => totalBytes > 0 ? bytesDownloaded / totalBytes : -1.0;

  String get formattedDownloaded => _formatBytes(bytesDownloaded);
  String get formattedTotal =>
      totalBytes > 0 ? _formatBytes(totalBytes) : '~555 MB';

  static String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Resolves the Gemma model via Play Asset Delivery.
///
/// With install-time delivery the model is always present after installation —
/// there is no download step. This service checks the asset pack status and
/// resolves the local model path.
///
/// The [progressStream] and [download] method are kept for API compatibility
/// with the onboarding screen; they complete immediately since the model is
/// already installed.
class ModelDownloadService {
  final _progressController = StreamController<DownloadProgress>.broadcast();

  /// Subscribe to track status. Emits a single completion event for PAD.
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  /// Resolves the model path from the asset pack.
  ///
  /// Returns the path on success, or null if the pack is not installed
  /// (only expected during local `flutter run` development; see the README
  /// at android/model_delivery/src/main/assets/model/README.md).
  Future<String?> download() async {
    try {
      final path = await FluxAiModelStorage.resolveModelPath();

      if (path == null) {
        const msg =
            'AI model asset pack is not installed. '
            'This is expected when running via flutter run locally. '
            'Install the app via a Play bundle or push the model manually via adb.';
        _emitError(msg);
        debugPrint('[ModelDeliveryService] $msg');
        return null;
      }

      _emit(
        DownloadProgress(bytesDownloaded: 0, totalBytes: 0, isComplete: true),
      );
      debugPrint('[ModelDeliveryService] Model ready at: $path');
      return path;
    } catch (e) {
      final msg = 'Failed to resolve model path: $e';
      _emitError(msg);
      return null;
    }
  }

  /// No-op for PAD — there is no active download to cancel.
  Future<void> cancel() async {}

  /// Releases the progress stream controller.
  void dispose() {
    if (!_progressController.isClosed) _progressController.close();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _emit(DownloadProgress progress) {
    if (!_progressController.isClosed) _progressController.add(progress);
  }

  void _emitError(String message) {
    debugPrint('[ModelDeliveryService] Error: $message');
    _emit(DownloadProgress(bytesDownloaded: 0, totalBytes: -1, error: message));
  }
}
