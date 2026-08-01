import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

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
  static const _prefKeyAccessToken = 'google_drive_access_token';
  static const _prefKeyTokenExpiry = 'google_drive_token_expiry';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

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
  // Web client ID from google-services.json (type 3 / server client).
  // Required by google_sign_in v7+ on Android.
  static const _webClientId =
      '318301516437-c3rpuj579o0eujq67nualbpme78thkja.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _googleSignIn.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  Future<void> _silentSignIn() async {
    try {
      await _ensureInitialized();

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
    await prefs.remove(_prefKeyAccessToken);
    await prefs.remove(_prefKeyTokenExpiry);
  }

  // ── Access token management (for background backup) ──────────────────────

  /// Persists the Drive access token so the background WorkManager worker
  /// can upload without needing the user-signed-in [GoogleSignInAccount].
  /// [expiry] is when the token stops being valid (UTC). Pass null to use
  /// a default of 50 minutes from now (tokens typically last 60 min).
  Future<void> saveAccessToken(String token, {DateTime? expiry}) async {
    final prefs = await SharedPreferences.getInstance();
    final exp =
        expiry ?? DateTime.now().toUtc().add(const Duration(minutes: 50));
    await prefs.setString(_prefKeyAccessToken, token);
    await prefs.setString(_prefKeyTokenExpiry, exp.toIso8601String());
  }

  /// Returns the cached Drive access token or null if none / expired.
  Future<String?> getStoredAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefKeyAccessToken);
    final expiryStr = prefs.getString(_prefKeyTokenExpiry);
    if (token == null || token.isEmpty) return null;
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isBefore(DateTime.now().toUtc())) {
        return null; // expired
      }
    }
    return token;
  }

  /// Clears the stored access token (e.g. on sign-out or auth failure).
  Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyAccessToken);
    await prefs.remove(_prefKeyTokenExpiry);
  }

  // ── Sign in ───────────────────────────────────────────────────────────────

  /// Triggers the Google Sign-In flow.
  /// Returns [true] on success, [false] on failure/cancellation.
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      await _ensureInitialized();

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

      // Best-effort: obtain a Drive access token now so the background
      // WorkManager worker can re-use it later without the user account.
      try {
        final scopes = ['https://www.googleapis.com/auth/drive.file'];
        final auth = await account.authorizationClient.authorizeScopes(scopes);
        await saveAccessToken(auth.accessToken);
      } catch (e) {
        debugPrint('[AuthService] Failed to cache Drive token: $e');
      }

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
      // Clear all user-owned DB data so the next sign-in starts clean.
      await AppDatabase.instance.clearUserData();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    } finally {
      _currentUser = null;
      _googleAccount = null;
      _initialized = false;
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
