import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the signed-in user's basic profile data.
class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  Map<String, String> toMap() => {
    'id': id,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl ?? '',
  };

  factory UserProfile.fromMap(Map<String, String> map) => UserProfile(
    id: map['id'] ?? '',
    displayName: map['displayName'] ?? '',
    email: map['email'] ?? '',
    photoUrl: map['photoUrl']?.isEmpty == true ? null : map['photoUrl'],
  );
}

/// Manages Google Sign-In and local session persistence.
class AuthService extends ChangeNotifier {
  static const _prefKeyId = 'user_id';
  static const _prefKeyName = 'user_name';
  static const _prefKeyEmail = 'user_email';
  static const _prefKeyPhoto = 'user_photo';

  UserProfile? _currentUser;
  GoogleSignInAccount? _googleAccount; // kept for Drive token access
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get currentUser => _currentUser;
  GoogleSignInAccount? get googleAccount => _googleAccount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _currentUser != null;

  // google_sign_in 7.x uses GoogleSignIn.instance singleton
  // Request Drive file scope so BackupService can upload backups.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  AuthService() {
    _restoreSession();
  }

  // ── Session persistence ───────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKeyId);
    if (id == null || id.isEmpty) return;

    // Restore the local profile so the UI shows the user immediately.
    _currentUser = UserProfile(
      id: id,
      displayName: prefs.getString(_prefKeyName) ?? '',
      email: prefs.getString(_prefKeyEmail) ?? '',
      photoUrl: prefs.getString(_prefKeyPhoto),
    );
    notifyListeners();

    // Silently re-establish the GoogleSignInAccount so Drive operations work
    // without requiring the user to sign in again on every app launch.
    await _silentSignIn();
  }

  /// Attempts to silently restore the GoogleSignInAccount from the platform's
  /// cached credentials. No UI is shown. If it fails (e.g. token revoked),
  /// _googleAccount stays null and the user will be prompted when they try
  /// to use a Drive feature.
  Future<void> _silentSignIn() async {
    try {
      await _googleSignIn.initialize();

      // Listen for the first sign-in event from the lightweight attempt.
      final eventFuture = _googleSignIn.authenticationEvents
          .where((e) => e is GoogleSignInAuthenticationEventSignIn)
          .map((e) => (e as GoogleSignInAuthenticationEventSignIn).user)
          .first
          .timeout(const Duration(seconds: 10));

      await _googleSignIn.attemptLightweightAuthentication();

      final account = await eventFuture;
      _googleAccount = account;
      notifyListeners();
      debugPrint('[AuthService] Silent sign-in restored: ${account.email}');
    } catch (e) {
      // Silent failure is expected when no cached credentials exist or
      // the token has been revoked. The user will be prompted on demand.
      debugPrint('[AuthService] Silent sign-in skipped: $e');
    }
  }

  Future<void> _persistSession(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyId, user.id);
    await prefs.setString(_prefKeyName, user.displayName);
    await prefs.setString(_prefKeyEmail, user.email);
    await prefs.setString(_prefKeyPhoto, user.photoUrl ?? '');
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyId);
    await prefs.remove(_prefKeyName);
    await prefs.remove(_prefKeyEmail);
    await prefs.remove(_prefKeyPhoto);
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  /// Triggers the Google Sign-In flow.
  /// Returns [true] on success, [false] on failure/cancellation.
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      // initialize() is idempotent — safe to call even if _silentSignIn
      // already called it during session restore.
      await _googleSignIn.initialize();

      late GoogleSignInAccount account;

      if (_googleSignIn.supportsAuthenticate()) {
        account = await _googleSignIn.authenticate();
      } else {
        await _googleSignIn.attemptLightweightAuthentication();
        account = await _googleSignIn.authenticationEvents
            .where((e) => e is GoogleSignInAuthenticationEventSignIn)
            .map((e) => (e as GoogleSignInAuthenticationEventSignIn).user)
            .first
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw Exception('Sign-in timed out'),
            );
      }

      _googleAccount = account;

      final profile = UserProfile(
        id: account.id,
        displayName: account.displayName ?? account.email.split('@').first,
        email: account.email,
        photoUrl: account.photoUrl,
      );

      _currentUser = profile;
      await _persistSession(profile);
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled')) {
        _setError('Sign-in was cancelled.');
      } else {
        _setError('Sign-in failed. Please try again.');
        debugPrint('[AuthService] signInWithGoogle error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    } finally {
      _currentUser = null;
      _googleAccount = null;
      await _clearSession();
      _setLoading(false);
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() => _clearError();
}
