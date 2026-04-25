import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/account_service.dart';
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
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;
  final CategoryService categoryService;
  final CurrencyService currencyService;
  final AccountService accountService;
  final TagService tagService;
  final TransactionService transactionService;
  final BackupService backupService;
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
  BudgetService get budgetService => widget.budgetService;
  BiometricService get biometricService => widget.biometricService;
  ScrollController? get scrollController => widget.scrollController;

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
                                errorBuilder: (_, __, ___) =>
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
                      onTap: () {},
                    ),
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

  Future<void> _runBackup(BuildContext context) async {
    var account = authService.googleAccount;
    if (account == null) {
      // Silent restore didn't get a Drive account — trigger interactive sign-in.
      final ok = await authService.signInWithGoogle();
      if (!ok || !context.mounted) return;
      account = authService.googleAccount;
      if (account == null) return;
    }

    final result = await backupService.backupToGoogleDrive(account);

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
        activeColor: color,
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

  @override
  void initState() {
    super.initState();
    _backupsFuture = widget.backupService.listBackups(widget.account);
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
                            'Select a backup to restore',
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
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final files = snap.data ?? [];

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
                    final dateStr = file.modifiedTime != null
                        ? DateFormat(
                            'MMM d, yyyy  HH:mm',
                          ).format(file.modifiedTime!.toLocal())
                        : '';
                    return InkWell(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
