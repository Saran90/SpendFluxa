import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// Result returned by [BackupService.backupToGoogleDrive] /
/// [BackupService.restoreFromDrive].
class BackupResult {
  final bool success;
  final String? fileId;
  final String? error;

  const BackupResult.success(this.fileId) : success = true, error = null;

  const BackupResult.failure(this.error) : success = false, fileId = null;
}

/// Metadata for a single backup file stored on Google Drive.
class DriveBackupFile {
  final String id;
  final String name;
  final DateTime? modifiedTime;

  const DriveBackupFile({
    required this.id,
    required this.name,
    this.modifiedTime,
  });
}

/// Handles backing up the SQLite database to Google Drive.
///
/// The backup is stored in the user's Drive under the app-specific folder
/// "SpendFluxa Backups" (appDataFolder scope is not used so the user can
/// see and manage their own backups).
///
/// Requires the [drive.DriveApi.driveFileScope] OAuth scope to be granted.
class BackupService extends ChangeNotifier {
  static const _prefKeyLastBackup = 'last_backup_timestamp';
  static const _prefKeyLastFileId = 'last_backup_file_id';
  static const _driveFolder = 'SpendFluxa Backups';
  static const _dbName = 'spendfluxa.db';

  bool _isRunning = false;
  DateTime? _lastBackup;
  String? _lastFileId;

  bool get isRunning => _isRunning;
  DateTime? get lastBackup => _lastBackup;
  String? get lastFileId => _lastFileId;

  BackupService() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_prefKeyLastBackup);
    if (ts != null) _lastBackup = DateTime.tryParse(ts);
    _lastFileId = prefs.getString(_prefKeyLastFileId);
    notifyListeners();
  }

  Future<void> _savePrefs(String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_prefKeyLastBackup, now.toIso8601String());
    await prefs.setString(_prefKeyLastFileId, fileId);
    _lastBackup = now;
    _lastFileId = fileId;
    notifyListeners();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Backs up the SQLite database to Google Drive.
  ///
  /// [account] must be a signed-in [GoogleSignInAccount]. The method will
  /// request Drive authorization via [authorizationClient.authorizeScopes]
  /// (which may show UI on first use) and then upload the database file.
  Future<BackupResult> backupToGoogleDrive(GoogleSignInAccount account) async {
    if (_isRunning) {
      return const BackupResult.failure('A backup is already in progress.');
    }

    _isRunning = true;
    notifyListeners();

    try {
      // 1. Obtain a Drive-scoped access token via the v7 authorization API.
      //    First try silently; if not yet granted, request with UI.
      final scopes = [drive.DriveApi.driveFileScope];
      GoogleSignInClientAuthorization? auth = await account.authorizationClient
          .authorizationForScopes(scopes);
      auth ??= await account.authorizationClient.authorizeScopes(scopes);

      final accessToken = auth.accessToken;

      // 2. Checkpoint WAL into the main file so the backup is a clean,
      //    self-contained DB with no dangling journal files, then close.
      final dbBeforeClose = await AppDatabase.instance.database;
      await dbBeforeClose.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await AppDatabase.instance.close();

      // 3. Locate the DB file on disk
      final dbDir = await getDatabasesPath();
      final dbFile = File(p.join(dbDir, _dbName));
      if (!await dbFile.exists()) {
        return const BackupResult.failure('Database file not found.');
      }

      // 4. Build an authenticated HTTP client
      final httpClient = _AuthenticatedClient(accessToken);
      final driveApi = drive.DriveApi(httpClient);

      // 5. Find or create the "SpendFluxa Backups" folder
      final folderId = await _ensureFolder(driveApi);

      // 6. Build the file name: spendfluxa_backup_YYYY-MM-DD_HH-mm.db
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}-'
          '${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'spendfluxa_backup_$stamp.db';

      // 7. Upload (create new file — keeps history)
      final fileBytes = await dbFile.readAsBytes();
      final media = drive.Media(
        Stream.value(fileBytes),
        fileBytes.length,
        contentType: 'application/octet-stream',
      );

      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = 'application/octet-stream';

      final uploaded = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      final fileId = uploaded.id ?? '';
      await _savePrefs(fileId);

      debugPrint('[BackupService] Uploaded $fileName (id=$fileId)');
      return BackupResult.success(fileId);
    } catch (e, st) {
      debugPrint('[BackupService] backup error: $e\n$st');
      return BackupResult.failure(e.toString());
    } finally {
      // Re-open the database
      await AppDatabase.instance.database;
      _isRunning = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Lists all backup files in the Drive folder, newest first.
  Future<List<DriveBackupFile>> listBackups(GoogleSignInAccount account) async {
    try {
      final scopes = [drive.DriveApi.driveFileScope];
      GoogleSignInClientAuthorization? auth = await account.authorizationClient
          .authorizationForScopes(scopes);
      auth ??= await account.authorizationClient.authorizeScopes(scopes);

      final driveApi = drive.DriveApi(_AuthenticatedClient(auth.accessToken));

      // Find the backup folder first — if it doesn't exist there are no backups.
      final folderResult = await driveApi.files.list(
        q:
            "mimeType='application/vnd.google-apps.folder' "
            "and name='$_driveFolder' "
            "and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );

      if (folderResult.files == null || folderResult.files!.isEmpty) {
        return [];
      }

      final folderId = folderResult.files!.first.id!;

      final result = await driveApi.files.list(
        q: "'$folderId' in parents and trashed=false",
        spaces: 'drive',
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,modifiedTime)',
      );

      return (result.files ?? [])
          .map(
            (f) => DriveBackupFile(
              id: f.id!,
              name: f.name ?? f.id!,
              modifiedTime: f.modifiedTime,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[BackupService] listBackups error: $e');
      return [];
    }
  }

  /// Downloads [fileId] from Drive and replaces the local database with it.
  ///
  /// The app must be restarted (or the DB re-initialised) after a successful
  /// restore for the changes to take effect.
  Future<BackupResult> restoreFromDrive(
    GoogleSignInAccount account,
    String fileId,
  ) async {
    if (_isRunning) {
      return const BackupResult.failure(
        'A backup operation is already in progress.',
      );
    }

    _isRunning = true;
    notifyListeners();

    try {
      final scopes = [drive.DriveApi.driveFileScope];
      GoogleSignInClientAuthorization? auth = await account.authorizationClient
          .authorizationForScopes(scopes);
      auth ??= await account.authorizationClient.authorizeScopes(scopes);

      final driveApi = drive.DriveApi(_AuthenticatedClient(auth.accessToken));

      // Download the file as a media stream.
      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Collect all bytes from the stream.
      final List<int> bytes = [];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      // Checkpoint WAL into the main DB file, then close the connection.
      // This ensures no -wal / -shm journal files are left alongside the DB
      // when we overwrite it, which would corrupt the restored data on next open.
      final dbBeforeClose = await AppDatabase.instance.database;
      await dbBeforeClose.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await AppDatabase.instance.close();

      // Write the downloaded bytes over the existing DB file.
      final dbDir = await getDatabasesPath();
      final dbFile = File(p.join(dbDir, _dbName));
      await dbFile.writeAsBytes(bytes, flush: true);

      // reopen() deletes any stale WAL/SHM files and opens a fresh connection.
      await AppDatabase.instance.reopen();

      debugPrint('[BackupService] Restored from Drive file $fileId');
      return BackupResult.success(fileId);
    } catch (e, st) {
      debugPrint('[BackupService] restore error: $e\n$st');
      // Make sure the DB is open even on failure.
      await AppDatabase.instance.database;
      return BackupResult.failure(e.toString());
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Returns the Drive folder ID for [_driveFolder], creating it if needed.
  Future<String> _ensureFolder(drive.DriveApi api) async {
    // Search for existing folder
    final result = await api.files.list(
      q:
          "mimeType='application/vnd.google-apps.folder' "
          "and name='$_driveFolder' "
          "and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }

    // Create the folder
    final folder = drive.File()
      ..name = _driveFolder
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(folder);
    return created.id!;
  }
}

// ── Authenticated HTTP client ─────────────────────────────────────────────────

/// Wraps an [http.Client] and injects the Bearer token on every request.
class _AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
