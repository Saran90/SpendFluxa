import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class ForceUpdateService {
  /// URL of a JSON file you control, e.g. a GitHub raw file.
  /// Shape: { "min_version": "1.2.0", "store_url": "https://..." }
  static const _configUrl =
      'https://raw.githubusercontent.com/Saran90/SpendFluxa/main/force_update.json';

  /// Returns the store URL if the installed version is below [minVersion],
  /// otherwise returns null (no update required).
  Future<String?> checkForceUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minVersion = data['min_version'] as String?;
      final storeUrl = data['store_url'] as String?;
      if (minVersion == null || storeUrl == null) return null;

      final info = await PackageInfo.fromPlatform();
      if (_isBelow(info.version, minVersion)) return storeUrl;
    } catch (_) {
      // Network error or parse failure — never block the user
    }
    return null;
  }

  /// Returns true if [current] is strictly below [minimum].
  /// Compares major.minor.patch numerically.
  bool _isBelow(String current, String minimum) {
    final c = _parts(current);
    final m = _parts(minimum);
    for (var i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false; // equal → no update needed
  }

  List<int> _parts(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}
