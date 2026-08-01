import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Gemma model file in app-specific storage.
class FluxAiModelStorage {
  FluxAiModelStorage._();

  static const _prefsKey = 'flux_ai_model_path';
  static const modelFileName = 'gemma-3n-e2b-int4.task';

  static Future<String> getModelDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(dir.path, 'flux_ai'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  static Future<String> getExpectedModelPath() async {
    final dir = await getModelDirectory();
    return p.join(dir, modelFileName);
  }

  static Future<String?> getSavedModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path == null) return null;
    if (!await File(path).exists()) return null;
    return path;
  }

  static Future<void> saveModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
  }

  static Future<bool> isModelAvailable() async {
    final path = await getSavedModelPath();
    if (path == null) return false;
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  }

  static Future<int?> getModelSizeBytes() async {
    final path = await getSavedModelPath();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.length();
  }
}
