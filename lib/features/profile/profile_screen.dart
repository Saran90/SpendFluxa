import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/auto_backup_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/budget_service.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/tag_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';
import '../accounts/accounts_screen.dart';
import '../categories/categories_screen.dart';
import '../tags/tags_screen.dart';
import '../help/help_screen.dart';
import '../onboarding/onboarding_tour_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final TagService tagService;
  final TransactionService transactionService;
  final BackupService backupService;
  final AutoBackupService autoBackupService;
  final BudgetService budgetService;
  final BiometricService biometricService;
  final ScrollController? scrollController;

  const ProfileScreen({
    super.key,
    required this.authService,
    required this.categoryService,
    required this.currencyService,
    required this.accountService,
    required this.tagService,
    required this.transactionService,
    required this.backupService,
    required this.autoBackupService,
    required this.budgetService,
    required this.biometricService,
    this.scrollController,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Expose service shorthands so existing helpers don't need changes.
  AuthService get authService => widget.authService;
  CategoryService get categoryService => widget.categoryService;
  CurrencyService get currencyService => widget.currencyService;
  AccountService get accountService => widget.accountService;
  TagService get tagService => widget.tagService;
  TransactionService get transactionService => widget.transactionService;
  BackupService get backupService => widget.backupService;
  AutoBackupService get autoBackupService => widget.autoBackupService;
  BudgetService get budgetService => widget.budgetService;
  BiometricService get biometricService => widget.biometricService;
  ScrollController? get scrollController => widget.scrollController;

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          // Show both the versionName (e.g. 1.1.0) and the buildNumber
          // (e.g. 4) so the user can tell at a glance which build is
          // actually installed.  Format: v1.1.0 (4)
          _appVersion = 'v${info.version} (${info.buildNumber})';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),

          // Avatar + name
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.splashGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: user?.photoUrl != null
                            ? Image.network(
                                user!.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _fallback(user.displayName),
                              )
                            : _fallback(user?.displayName ?? '?'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Settings tiles
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ── Preferences ──────────────────────────────────────
                    ListenableBuilder(
                      listenable: currencyService,
                      builder: (context, _) => _tile(
                        icon: Icons.currency_exchange_rounded,
                        label: 'Currency',
                        color: const Color(0xFF2D9E6B),
                        trailing: Text(
                          currencyService.code,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () => _showCurrencyPicker(context),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Accounts',
                      color: const Color(0xFF3498DB),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountsScreen(
                            accountService: accountService,
                            currencyService: currencyService,
                          ),
                        ),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.category_rounded,
                      label: 'Categories',
                      color: const Color(0xFF9B59B6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoriesScreen(
                            categoryService: categoryService,
                          ),
                        ),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.label_rounded,
                      label: 'Tags',
                      color: const Color(0xFFFF9800),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TagsScreen(
                            tagService: tagService,
                            transactionService: transactionService,
                            currencyService: currencyService,
                          ),
                        ),
                      ),
                    ),
                    _divider(),
                    // Biometric lock toggle — only shown when device supports it
                    ListenableBuilder(
                      listenable: biometricService,
                      builder: (context, _) {
                        if (!biometricService.isAvailable) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _switchTile(
                              icon: Icons.fingerprint_rounded,
                              label: 'Biometric Lock',
                              subtitle: 'Require fingerprint / face on launch',
                              color: const Color(0xFF5C6BC0),
                              value: biometricService.isEnabled,
                              onChanged: (val) async {
                                final ok = await biometricService.setEnabled(
                                  val,
                                );
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Biometric authentication failed.',
                                      ),
                                      backgroundColor: AppColors.accent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            _divider(),
                          ],
                        );
                      },
                    ),
                    // ── Data & Backup ─────────────────────────────────────
                    _groupDivider(),
                    ListenableBuilder(
                      listenable: backupService,
                      builder: (context, _) {
                        final last = backupService.lastBackup;
                        final subtitle = last != null
                            ? 'Last: ${DateFormat('MMM d, yyyy  HH:mm').format(last)}'
                            : 'Never backed up';
                        return _tile(
                          icon: Icons.backup_rounded,
                          label: 'Backup to Google Drive',
                          color: const Color(0xFF4285F4),
                          trailing: backupService.isRunning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF4285F4),
                                    ),
                                  ),
                                )
                              : Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                          showChevron: false,
                          onTap: backupService.isRunning
                              ? () {}
                              : () => _runBackup(context),
                        );
                      },
                    ),
                    _divider(),
                    // ── Auto-Backup ───────────────────────────────────────
                    ListenableBuilder(
                      listenable: autoBackupService,
                      builder: (context, _) => _tile(
                        icon: Icons.schedule_rounded,
                        label: 'Auto-Backup',
                        color: const Color(0xFF7B61FF),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (autoBackupService.enabled)
                              Text(
                                autoBackupService.timeLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Switch.adaptive(
                              value: autoBackupService.enabled,
                              onChanged: (val) =>
                                  _onAutoBackupToggle(context, val),
                              activeThumbColor: const Color(0xFF7B61FF),
                              activeTrackColor: const Color(
                                0xFF7B61FF,
                              ).withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                        showChevron: false,
                        onTap: autoBackupService.enabled
                            ? () => _showAutoBackupSettings(context)
                            : () => _onAutoBackupToggle(context, true),
                      ),
                    ),
                    _divider(),
                    ListenableBuilder(
                      listenable: backupService,
                      builder: (context, _) => _tile(
                        icon: Icons.restore_rounded,
                        label: 'Restore from Google Drive',
                        color: const Color(0xFF34A853),
                        showChevron: backupService.isRunning ? false : true,
                        trailing: backupService.isRunning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF34A853),
                                  ),
                                ),
                              )
                            : null,
                        onTap: backupService.isRunning
                            ? () {}
                            : () => _showRestorePicker(context),
                      ),
                    ),
                    // ── Info & Legal ──────────────────────────────────────
                    _groupDivider(),
                    _tile(
                      icon: Icons.lock_rounded,
                      label: 'Privacy & Security',
                      color: const Color(0xFF9B59B6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.help_rounded,
                      label: 'Help & Support',
                      color: const Color(0xFF3498DB),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.tour_rounded,
                      label: 'View App Tour',
                      color: const Color(0xFF9B59B6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OnboardingTourScreen(),
                          fullscreenDialog: true,
                        ),
                      ),
                    ),
                    if (_appVersion.isNotEmpty) ...[
                      _divider(),
                      _tile(
                        icon: Icons.info_outline_rounded,
                        label: 'App Version',
                        color: AppColors.textSecondary,
                        trailing: Text(
                          _appVersion,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        showChevron: false,
                        onTap: () {},
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _tile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  color: AppColors.accent,
                  textColor: AppColors.accent,
                  showChevron: false,
                  onTap: () async {
                    await authService.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Auto-Backup ───────────────────────────────────────────────────────────

  /// Called when the user flips the Auto-Backup toggle.
  Future<void> _onAutoBackupToggle(BuildContext context, bool enable) async {
    if (!enable) {
      await autoBackupService.setEnabled(false);
      await autoBackupService.clearTargetFileId();
      return;
    }

    // Need a signed-in Google account to proceed
    var account = authService.googleAccount;
    if (account == null) {
      final ok = await authService.signInWithGoogle();
      if (!ok || !context.mounted) return;
      account = authService.googleAccount;
      if (account == null) return;
    }

    await autoBackupService.setEnabled(true);

    if (!context.mounted) return;

    // If we already have a stored target file ID, nothing more to do
    if (autoBackupService.targetFileId != null) {
      _showAutoBackupSettings(context);
      return;
    }

    // Check Drive for existing backups — use the most recent one as target
    _showAutoBackupProgress(context, message: 'Checking Google Drive…');
    final existingFiles = await backupService.listBackups(account);

    if (!context.mounted) return;
    Navigator.of(context).pop(); // close progress dialog

    if (!context.mounted) return;

    if (existingFiles.isNotEmpty) {
      // Let the user pick which existing backup to use as the recurring target
      final chosen = await showModalBottomSheet<DriveBackupFile>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _AutoBackupFilePickerSheet(files: existingFiles),
      );

      if (!context.mounted) return;

      if (chosen == null) {
        // User dismissed the sheet (swiped down) — disable the toggle
        await autoBackupService.setEnabled(false);
        return;
      }

      if (chosen.id == '__new__') {
        // User chose "Create a new backup file"
        _showAutoBackupProgress(
          context,
          message: 'Creating new backup on Google Drive…',
        );
        final result = await backupService.backupToGoogleDrive(account);
        if (context.mounted) Navigator.of(context).pop();
        if (!context.mounted) return;

        if (result.success && result.fileId != null) {
          await autoBackupService.setTargetFileId(result.fileId!);
          await autoBackupService.markBackedUpToday();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Auto-Backup enabled. New backup created on Google Drive.',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF7B61FF),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          if (context.mounted) _showAutoBackupSettings(context);
        } else {
          await autoBackupService.setEnabled(false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Could not create backup: ${result.error ?? 'Unknown error'}',
                ),
                backgroundColor: AppColors.accent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
        return;
      }

      await autoBackupService.setTargetFileId(chosen.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-Backup enabled. Daily backups will overwrite "${chosen.name}".',
          ),
          backgroundColor: const Color(0xFF7B61FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      _showAutoBackupSettings(context);
    } else {
      // No backups on Drive at all — create the first one now
      _showAutoBackupProgress(
        context,
        message: 'No existing backup found. Creating first backup…',
      );
      final result = await backupService.backupToGoogleDrive(account);
      if (context.mounted) Navigator.of(context).pop(); // close progress dialog

      if (!context.mounted) return;
      if (result.success && result.fileId != null) {
        await autoBackupService.setTargetFileId(result.fileId!);
        await autoBackupService.markBackedUpToday();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Auto-Backup enabled. First backup created on Google Drive.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7B61FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (context.mounted) _showAutoBackupSettings(context);
      } else {
        // Backup failed — disable auto-backup
        await autoBackupService.setEnabled(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not create backup: ${result.error ?? 'Unknown error'}',
              ),
              backgroundColor: AppColors.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _showAutoBackupProgress(
    BuildContext context, {
    String message = 'Creating first backup on Google Drive…',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(width: 20),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoBackupSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _AutoBackupSettingsSheet(autoBackupService: autoBackupService),
    );
  }

  /// Called on app launch (from MainShell) to run a due auto-backup silently.
  Future<void> runAutoBackupIfDue() async {
    if (!autoBackupService.isDueNow()) return;
    final account = authService.googleAccount;
    if (account == null) return;

    final targetId = autoBackupService.targetFileId;
    BackupResult result;
    if (targetId != null) {
      result = await backupService.overwriteBackup(account, targetId);
      // If overwrite created a new file (fallback), update the target ID
      if (result.success &&
          result.fileId != null &&
          result.fileId != targetId) {
        await autoBackupService.setTargetFileId(result.fileId!);
      }
    } else {
      result = await backupService.backupToGoogleDrive(account);
      if (result.success && result.fileId != null) {
        await autoBackupService.setTargetFileId(result.fileId!);
      }
    }

    if (result.success) {
      await autoBackupService.markBackedUpToday();
      debugPrint('[AutoBackup] Daily backup completed.');
    } else {
      debugPrint('[AutoBackup] Daily backup failed: ${result.error}');
    }
  }

  Future<void> _runBackup(BuildContext context) async {
    var account = authService.googleAccount;
    if (account == null) {
      // Silent sign-in didn't get a Drive account — trigger interactive sign-in.
      final ok = await authService.signInWithGoogle();
      if (!ok || !context.mounted) return;
      account = authService.googleAccount;
      if (account == null) return;
    }

    // Show the naming sheet and let the user optionally name the backup.
    final capturedAccount = account;
    final chosenName = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BackupNameSheet(
        defaultFileName: backupService.generateDefaultFileName(),
        account: capturedAccount,
        backupService: backupService,
      ),
    );

    // null = user dismissed the sheet → cancel
    if (chosenName == null || !context.mounted) return;

    final result = await backupService.backupToGoogleDrive(
      capturedAccount,
      customFileName: chosenName,
    );

    if (!context.mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Backup uploaded to Google Drive'),
            ],
          ),
          backgroundColor: const Color(0xFF2D9E6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: ${result.error}'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showRestorePicker(BuildContext context) async {
    var account = authService.googleAccount;
    if (account == null) {
      // Silent restore didn't get a Drive account — trigger interactive sign-in.
      final ok = await authService.signInWithGoogle();
      if (!ok || !context.mounted) return;
      account = authService.googleAccount;
      if (account == null) return;
    }

    // Show the sheet immediately with a loading state.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _RestorePickerSheet(
        account: account!,
        backupService: backupService,
        // Pass the outer screen context so _runRestore can use it after
        // the sheet is dismissed (sheetCtx becomes unmounted on pop).
        onRestore: (fileId) => _runRestore(context, sheetCtx, fileId),
      ),
    );
  }

  Future<void> _runRestore(
    BuildContext screenCtx,
    BuildContext sheetCtx,
    String fileId,
  ) async {
    final account = authService.googleAccount;
    if (account == null) return;

    // Confirm before overwriting local data.
    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Restore Backup?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'This will replace all current data with the selected backup. '
          'This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Close the picker sheet.
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();

    // Run the restore — sheetCtx is now unmounted, use screenCtx from here on.
    final result = await backupService.restoreFromDrive(account, fileId);

    if (!screenCtx.mounted) return;

    if (result.success) {
      // Reload every service's in-memory cache from the restored DB so the
      // UI reflects the restored data immediately — no restart needed.
      await Future.wait([
        accountService.reload(),
        categoryService.reload(),
        tagService.reload(),
        budgetService.reload(),
        transactionService.reload(),
      ]);

      if (!screenCtx.mounted) return;
      ScaffoldMessenger.of(screenCtx).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Data restored successfully from Google Drive.'),
            ],
          ),
          backgroundColor: const Color(0xFF2D9E6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(screenCtx).showSnackBar(
        SnackBar(
          content: Text('Restore failed: ${result.error}'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Currency',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...AppCurrency.values.map((c) {
                final isSelected = currencyService.current == c;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D9E6B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${c.symbol}  •  ${c.code}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 22,
                        )
                      : null,
                  onTap: () {
                    currencyService.setCurrency(c);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(String name) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color? textColor,
    Widget? trailing,
    bool showChevron = true,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
      trailing:
          trailing ??
          (showChevron
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textLight,
                  size: 20,
                )
              : null),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        activeTrackColor: color.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    indent: 72,
    endIndent: 20,
    color: Color(0xFFF0F2F5),
  );

  Widget _groupDivider() => const Divider(
    height: 1,
    indent: 0,
    endIndent: 0,
    color: Color(0xFFEEF0F3),
    thickness: 6,
  );
}

// ── Backup name bottom sheet ──────────────────────────────────────────────────

/// Bottom sheet shown before a manual backup. The user can optionally enter a
/// custom name for the file. Tapping "Back up" returns the chosen (or default)
/// file name to the caller. Dismissing the sheet returns null (cancel).
class _BackupNameSheet extends StatefulWidget {
  final String defaultFileName;
  final GoogleSignInAccount account;
  final BackupService backupService;

  const _BackupNameSheet({
    required this.defaultFileName,
    required this.account,
    required this.backupService,
  });

  @override
  State<_BackupNameSheet> createState() => _BackupNameSheetState();
}

class _BackupNameSheetState extends State<_BackupNameSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Ensures the name ends with .db
  String _normalise(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return widget.defaultFileName;
    return trimmed.endsWith('.db') ? trimmed : '$trimmed.db';
  }

  Future<void> _submit() async {
    final finalName = _normalise(_controller.text);

    setState(() {
      _error = null;
      _checking = true;
    });

    // Validate: check for duplicate only when the user typed a custom name
    if (_controller.text.trim().isNotEmpty) {
      final exists = await widget.backupService.checkBackupNameExists(
        widget.account,
        finalName,
      );
      if (!mounted) return;
      if (exists) {
        setState(() {
          _checking = false;
          _error =
              '"$finalName" already exists on Drive. Choose a different name.';
        });
        return;
      }
    }

    setState(() => _checking = false);
    if (mounted) Navigator.of(context).pop(finalName);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.backup_rounded,
                      color: Color(0xFF4285F4),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup to Google Drive',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Optionally give this backup a custom name',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // File name field
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Backup name (optional)',
                  hintText: widget.defaultFileName,
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                  errorText: _error,
                  errorMaxLines: 2,
                  helperText: 'Leave blank to use the default timestamp name',
                  helperStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  suffixText: '.db',
                  suffixStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF4285F4),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),

              // Back up button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Back Up',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Restore picker bottom sheet ───────────────────────────────────────────────

class _RestorePickerSheet extends StatefulWidget {
  final GoogleSignInAccount account;
  final BackupService backupService;
  final void Function(String fileId) onRestore;

  const _RestorePickerSheet({
    required this.account,
    required this.backupService,
    required this.onRestore,
  });

  @override
  State<_RestorePickerSheet> createState() => _RestorePickerSheetState();
}

class _RestorePickerSheetState extends State<_RestorePickerSheet> {
  late Future<List<DriveBackupFile>> _backupsFuture;
  // Local mutable copy so we can remove items without re-fetching
  List<DriveBackupFile>? _files;
  // Tracks which file IDs are currently being deleted
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    _backupsFuture = widget.backupService.listBackups(widget.account).then((
      files,
    ) {
      if (mounted) setState(() => _files = files);
      return files;
    });
  }

  Future<void> _confirmDelete(DriveBackupFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Backup?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'This will permanently delete "${file.name}" from Google Drive. '
          'This cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting.add(file.id));

    final result = await widget.backupService.deleteBackup(
      widget.account,
      file.id,
    );

    if (!mounted) return;

    setState(() {
      _deleting.remove(file.id);
      if (result.success) {
        _files?.removeWhere((f) => f.id == file.id);
      }
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${result.error}'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34A853).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restore_rounded,
                        color: Color(0xFF34A853),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Restore from Google Drive',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to restore • Swipe left to delete',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
              ],
            ),
          ),

          // Backup list
          Expanded(
            child: FutureBuilder<List<DriveBackupFile>>(
              future: _backupsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done &&
                    _files == null) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final files = _files ?? snap.data ?? [];

                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No backups found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create a backup first to restore from Drive.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 56,
                    color: Color(0xFFF0F2F5),
                  ),
                  itemBuilder: (_, i) {
                    final file = files[i];
                    final isDeleting = _deleting.contains(file.id);
                    final dateStr = file.modifiedTime != null
                        ? DateFormat(
                            'MMM d, yyyy  HH:mm',
                          ).format(file.modifiedTime!.toLocal())
                        : '';

                    return Dismissible(
                      key: ValueKey(file.id),
                      direction: DismissDirection.endToStart,
                      // Confirmation happens inside _confirmDelete, so we
                      // return false here to prevent automatic dismissal.
                      confirmDismiss: (_) async {
                        await _confirmDelete(file);
                        return false; // we manage removal ourselves
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_rounded,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                      child: isDeleting
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4285F4,
                                      ).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF4285F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Deleting ${file.name}…',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : InkWell(
                              onTap: () => widget.onRestore(file.id),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4285F4,
                                        ).withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.storage_rounded,
                                        color: Color(0xFF4285F4),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            file.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (dateStr.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              dateStr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Delete icon button
                                    InkWell(
                                      onTap: () => _confirmDelete(file),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: AppColors.accent.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textLight,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Auto-Backup file picker sheet ────────────────────────────────────────────

/// Shown when the user enables Auto-Backup and existing Drive backups are found.
/// Returns the chosen [DriveBackupFile], or null if dismissed.
class _AutoBackupFilePickerSheet extends StatelessWidget {
  final List<DriveBackupFile> files;

  const _AutoBackupFilePickerSheet({required this.files});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B61FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.folder_open_rounded,
                        color: Color(0xFF7B61FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Backup File',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Daily backups will overwrite the file you choose',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
              ],
            ),
          ),

          // ── File list ────────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: files.length + 1, // +1 for "Create new" option
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 56,
                color: Color(0xFFF0F2F5),
              ),
              itemBuilder: (_, i) {
                // Last item — "Create a new backup file" option
                if (i == files.length) {
                  return InkWell(
                    onTap: () => Navigator.pop(
                      context,
                      const DriveBackupFile(id: '__new__', name: '__new__'),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2D9E6B,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF2D9E6B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create a new backup file',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D9E6B),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'A fresh backup will be created on Drive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final file = files[i];
                final dateStr = file.modifiedTime != null
                    ? DateFormat(
                        'MMM d, yyyy  HH:mm',
                      ).format(file.modifiedTime!.toLocal())
                    : '';

                return InkWell(
                  onTap: () => Navigator.pop(context, file),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4285F4,
                            ).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storage_rounded,
                            color: Color(0xFF4285F4),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Auto-Backup settings sheet ────────────────────────────────────────────────

class _AutoBackupSettingsSheet extends StatefulWidget {
  final AutoBackupService autoBackupService;

  const _AutoBackupSettingsSheet({required this.autoBackupService});

  @override
  State<_AutoBackupSettingsSheet> createState() =>
      _AutoBackupSettingsSheetState();
}

class _AutoBackupSettingsSheetState extends State<_AutoBackupSettingsSheet> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.autoBackupService.hour;
    _minute = widget.autoBackupService.minute;
  }

  String get _timeLabel {
    final h = _hour % 12 == 0 ? 12 : _hour % 12;
    final m = _minute.toString().padLeft(2, '0');
    final period = _hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      helpText: 'Set daily backup time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
      await widget.autoBackupService.setTime(_hour, _minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF7B61FF),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Auto-Backup Settings',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'The database will be backed up to Google Drive once per day '
                'at the selected time, even when the app is closed. '
                'If a backup is missed (no network or app was off), '
                'it will run automatically the next time you open the app.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time picker row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7B61FF,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF7B61FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daily backup time',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeLabel,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7B61FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF7B61FF),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info note
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF4285F4),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Each daily backup overwrites the same file on Google Drive. '
                        'The backup runs at your chosen time even when the app is closed. '
                        'If it was missed, it will catch up automatically on next app launch.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Done button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
