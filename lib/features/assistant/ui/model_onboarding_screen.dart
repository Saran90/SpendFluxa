import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/assistant_providers.dart';

/// Shown when the Gemma model asset pack is not yet available.
///
/// With Play Asset Delivery (install-time), this screen should normally
/// never appear for Play-installed builds — the model ships with the app.
///
/// It surfaces only during local development (flutter run) where the asset
/// pack is not present, or on the first launch after a fresh install before
/// the status provider has resolved.
class ModelOnboardingScreen extends ConsumerStatefulWidget {
  const ModelOnboardingScreen({super.key});

  @override
  ConsumerState<ModelOnboardingScreen> createState() =>
      _ModelOnboardingScreenState();
}

class _ModelOnboardingScreenState extends ConsumerState<ModelOnboardingScreen> {
  bool _checking = false;
  String? _error;

  Future<void> _retry() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    // Invalidate the status provider so it re-checks the asset pack.
    ref.invalidate(modelStatusProvider);

    // Give the provider a moment to resolve before removing the spinner.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Flux AI',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Set up Flux AI',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Flux AI uses an on-device language model to answer your '
                'questions and help manage your finances — completely offline. '
                'Your financial data never leaves your phone.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              _InfoCard(
                icon: Icons.memory_rounded,
                label: 'Model',
                value: 'Gemma 3 1B (Google)',
              ),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.cloud_download_rounded,
                label: 'Delivery',
                value: 'Shipped with the app via Google Play',
              ),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.lock_rounded,
                label: 'Privacy',
                value: 'Runs fully on-device. No data leaves your phone.',
              ),
              const SizedBox(height: 24),

              // Status area
              if (_checking) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text(
                        'Checking AI model…',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Dev-mode notice — explains why the model isn't found locally.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFE65100),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Model not found',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The AI model is delivered via Google Play Asset Delivery '
                        'and is installed automatically when you install the app '
                        'from the Play Store.\n\n'
                        'If you are running a debug build locally, push the model '
                        'file manually via adb:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFBF360C),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '# Option 1 — world-readable path:\n'
                          'adb shell mkdir -p /data/local/tmp/llm\n'
                          'adb push gemma3-1b-it-int4.task \\\n'
                          '  /data/local/tmp/llm/\n\n'
                          '# Option 2 — app-private files dir:\n'
                          'adb push gemma3-1b-it-int4.task \\\n'
                          '  /data/data/com.yuklore.spendflux/files/',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Color(0xFF90EE90),
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checking ? null : _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Check Again',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Not now',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECF0F1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
