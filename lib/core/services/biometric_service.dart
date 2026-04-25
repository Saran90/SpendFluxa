import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages biometric authentication availability and the user's opt-in toggle.
class BiometricService extends ChangeNotifier {
  static const _prefKeyEnabled = 'biometric_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _isEnabled = false;
  bool _isAvailable = false;

  /// Whether the device supports biometrics and has enrolled credentials.
  bool get isAvailable => _isAvailable;

  /// Whether the user has opted in to biometric lock.
  bool get isEnabled => _isEnabled && _isAvailable;

  BiometricService() {
    _init();
  }

  Future<void> _init() async {
    await _checkAvailability();
    await _loadPrefs();
  }

  Future<void> _checkAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      _isAvailable = canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('[BiometricService] availability check error: $e');
      _isAvailable = false;
    }
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKeyEnabled) ?? false;
    notifyListeners();
  }

  /// Toggles biometric lock on or off.
  ///
  /// When enabling, performs an immediate authentication challenge to confirm
  /// the user can actually authenticate before saving the preference.
  /// Returns [true] if the toggle succeeded, [false] if auth was denied.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      // Verify the user can authenticate before enabling.
      final authenticated = await authenticate(
        reason: 'Confirm your identity to enable biometric lock',
      );
      if (!authenticated) return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, value);
    _isEnabled = value;
    notifyListeners();
    return true;
  }

  /// Prompts the user for biometric (or device credential) authentication.
  ///
  /// Returns [true] if authentication succeeded, [false] otherwise.
  Future<bool> authenticate({
    String reason = 'Authenticate to access SpendFluxa',
  }) async {
    if (!_isAvailable) return true; // no biometrics → always allow

    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback
          stickyAuth: true, // keep prompt alive if app goes background
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
