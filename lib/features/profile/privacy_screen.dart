import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.splashGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 24, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy & Security',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'How SpendFlux handles your data',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Last updated ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text(
                'Last updated: April 2026',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ),

          // ── Intro card ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your Privacy, Our Priority',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SpendFlux is built with a privacy-first philosophy. '
                    'Your financial data is personal, and we treat it that way. '
                    'This document explains exactly what data we collect, '
                    'where it lives, and who can access it — in plain language.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Section: Data Storage ────────────────────────────────────────
          _sectionHeader('Data Storage'),
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                children: [
                  _PolicyPoint(
                    icon: Icons.phone_android_rounded,
                    iconColor: const Color(0xFF3498DB),
                    title: 'Stored only on your device',
                    body:
                        'All your transactions, accounts, budgets, categories, '
                        'and tags are stored exclusively in a local SQLite '
                        'database on your phone. No data is ever sent to any '
                        'external server or third-party service.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.cloud_off_rounded,
                    iconColor: const Color(0xFF9B59B6),
                    title: 'No cloud sync or remote database',
                    body:
                        'SpendFlux does not operate any backend servers, '
                        'databases, or cloud infrastructure. There is no '
                        'account system, no sync service, and no remote '
                        'storage managed by the app.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF2D9E6B),
                    title: 'Data stays private by design',
                    body:
                        'Because your data never leaves your device (except '
                        'for your own Google Drive backup — see below), '
                        'it is impossible for anyone other than you to '
                        'access your financial records.',
                  ),
                ],
              ),
            ),
          ),

          // ── Section: Google Drive Backup ─────────────────────────────────
          _sectionHeader('Google Drive Backup'),
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                children: [
                  _PolicyPoint(
                    icon: Icons.drive_folder_upload_rounded,
                    iconColor: const Color(0xFF4285F4),
                    title: 'Backed up to your own Drive',
                    body:
                        'When you choose to back up, the app uploads a copy '
                        'of your local database directly to your personal '
                        'Google Drive account — specifically to a folder '
                        'named "SpendFlux Backups". Only you have access '
                        'to this folder.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.person_off_rounded,
                    iconColor: const Color(0xFF34A853),
                    title: 'We cannot access your backup',
                    body:
                        'The backup is stored under your Google account using '
                        'the Drive File scope, which grants access only to '
                        'files created by this app. SpendFlux has no '
                        'visibility into your Drive and cannot read, modify, '
                        'or delete any of your files.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.toggle_on_rounded,
                    iconColor: const Color(0xFFFF9800),
                    title: 'Backup is always optional',
                    body:
                        'The backup feature is entirely opt-in. You can use '
                        'SpendFlux indefinitely without ever connecting '
                        'Google Drive. Your data remains on-device regardless.',
                  ),
                ],
              ),
            ),
          ),

          // ── Section: Google Sign-In ──────────────────────────────────────
          _sectionHeader('Google Sign-In'),
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                children: [
                  _PolicyPoint(
                    icon: Icons.account_circle_rounded,
                    iconColor: const Color(0xFF4285F4),
                    title: 'Basic profile only',
                    body:
                        'Signing in with Google allows the app to display '
                        'your name, email address, and profile photo inside '
                        'the app. This information is stored locally on your '
                        'device and is used solely for personalisation.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.block_rounded,
                    iconColor: AppColors.accent,
                    title: 'No sensitive Google data accessed',
                    body:
                        'SpendFlux does not request access to your Gmail, '
                        'Google Contacts, Calendar, or any other Google '
                        'service. The only permission requested beyond basic '
                        'profile is the Drive File scope, and only when you '
                        'initiate a backup or restore.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.no_accounts_rounded,
                    iconColor: const Color(0xFF9B59B6),
                    title: 'Profile data is not shared',
                    body:
                        'Your Google profile details are never transmitted '
                        'to any server, analytics platform, or third party. '
                        'They exist only in your device\'s local storage.',
                  ),
                ],
              ),
            ),
          ),

          // ── Section: Data Sharing ────────────────────────────────────────
          _sectionHeader('Data Sharing & Third Parties'),
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                children: [
                  _PolicyPoint(
                    icon: Icons.share_rounded,
                    iconColor: AppColors.accent,
                    title: 'We do not share your data',
                    body:
                        'SpendFlux does not sell, rent, trade, or share '
                        'your personal or financial data with any third '
                        'party, advertiser, or analytics provider — ever.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.analytics_rounded,
                    iconColor: const Color(0xFF607D8B),
                    title: 'No analytics or tracking',
                    body:
                        'The app contains no analytics SDKs, crash reporting '
                        'services, advertising frameworks, or tracking '
                        'libraries. Your usage patterns and financial '
                        'behaviour are never observed or recorded.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.wifi_off_rounded,
                    iconColor: const Color(0xFF3498DB),
                    title: 'No network requests (except Drive)',
                    body:
                        'The app makes no network requests during normal '
                        'use. The only outbound connections are to Google\'s '
                        'OAuth and Drive APIs, and only when you explicitly '
                        'sign in or trigger a backup/restore.',
                  ),
                ],
              ),
            ),
          ),

          // ── Section: Your Rights ─────────────────────────────────────────
          _sectionHeader('Your Rights & Control'),
          SliverToBoxAdapter(
            child: _Card(
              child: Column(
                children: [
                  _PolicyPoint(
                    icon: Icons.delete_forever_rounded,
                    iconColor: AppColors.accent,
                    title: 'Delete your data anytime',
                    body:
                        'You can delete all app data at any time by '
                        'uninstalling SpendFlux. This permanently removes '
                        'the local database from your device. To also remove '
                        'Drive backups, delete the "SpendFlux Backups" '
                        'folder from your Google Drive.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFF9B59B6),
                    title: 'Sign out at any time',
                    body:
                        'You can sign out of your Google account from the '
                        'Profile screen at any time. This removes your '
                        'profile details from the device and disconnects '
                        'Drive access, while keeping your local financial '
                        'data intact.',
                  ),
                  _divider(),
                  _PolicyPoint(
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF2D9E6B),
                    title: 'Full data portability',
                    body:
                        'Your data is stored in a standard SQLite file. '
                        'Drive backups are plain database files you can '
                        'download and inspect at any time. You are never '
                        'locked in.',
                  ),
                ],
              ),
            ),
          ),

          // ── Summary banner ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.splashGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Your data belongs to you — and only you. '
                        'SpendFlux is a tool that works for you, '
                        'not the other way around.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  static Widget _divider() => const Divider(
    height: 1,
    indent: 48,
    endIndent: 0,
    color: Color(0xFFF0F2F5),
  );
}

// ── Reusable card wrapper ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
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
        child: child,
      ),
    );
  }
}

// ── Single policy point row ───────────────────────────────────────────────────

class _PolicyPoint extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _PolicyPoint({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
