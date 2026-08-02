import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../pigeon/flux_ai_api.g.dart';

/// Resolves and caches the Gemma model path from the Play Asset Delivery pack.
///
/// With install-time delivery the pack is available immediately after
/// installation, so [resolveModelPath] should always succeed on a Play-installed
/// build.  During local `flutter run` development the pack is not present;
/// in that case the method returns null and the engine logs a hint.
class FluxAiModelStorage {
  FluxAiModelStorage._();

  static const _prefsKey = 'flux_ai_model_path';

  // ── Path resolution ────────────────────────────────────────────────────────

  /// Returns the absolute path to `gemma3-1b-it-int4.task` inside the
  /// install-time asset pack, via the native [FluxAiHostApi.getAssetPackModelPath].
  ///
  /// The resolved path is cached in [SharedPreferences] so subsequent calls
  /// are instant (the asset pack location is stable for the lifetime of the
  /// install).
  ///
  /// Returns null if the asset pack is not installed (local dev / sideload).
  static Future<String?> resolveModelPath() async {
    // Fast path: cached path still exists on disk.
    final cached = await getSavedModelPath();
    if (cached != null) return cached;

    // Query the native layer for the asset pack location.
    final api = FluxAiHostApi();
    final status = await api.getAssetPackModelPath();

    if (!status.isAvailable || status.modelPath == null) {
      return null;
    }

    // Cache it so we don't cross the platform channel on every app start.
    await _saveModelPath(status.modelPath!);
    return status.modelPath;
  }

  // ── Status helpers ─────────────────────────────────────────────────────────

  /// Returns true if the model is available via the asset pack.
  static Future<bool> isModelAvailable() async {
    final path = await resolveModelPath();
    if (path == null) return false;
    return File(path).existsSync();
  }

  /// Returns the cached resolved path if present and the file still exists.
  static Future<String?> getSavedModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path == null) return null;
    if (!File(path).existsSync()) {
      // Asset pack was updated or path changed — clear the stale cache.
      await prefs.remove(_prefsKey);
      return null;
    }
    return path;
  }

  static Future<int?> getModelSizeBytes() async {
    final path = await getSavedModelPath();
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.length();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<void> _saveModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
  }
}
