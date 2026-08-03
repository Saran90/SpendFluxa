import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/assistant_providers.dart';

/// Step 1 of payment method selection — shows account type chips:
/// Bank / Credit Card / Wallet / Cash / Savings.
/// Tapping Cash skips the sub-picker and goes straight to date.
/// All other types open a sub-picker with the user's actual accounts.
class GuidedAccountPicker extends ConsumerWidget {
  const GuidedAccountPicker({super.key});

  static const _types = [
    AccountType.bank,
    AccountType.creditCard,
    AccountType.wallet,
    AccountType.cash,
    AccountType.savings,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountService = ref.watch(accountServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botAvatar(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _bubbleDecor(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Which payment method?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      return _TypeChip(
                        type: type,
                        onTap: () {
                          final accounts = accountService.all
                              .where((a) => a.type == type)
                              .toList();
                          ref
                              .read(assistantSessionProvider.notifier)
                              .resolveGuidedAccountType(
                                type.name,
                                type.label,
                                accounts,
                              );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Sub-picker: specific accounts of the chosen type ─────────────────────────

/// Step 2 — shows the actual named accounts of the selected type.
class GuidedAccountSubPicker extends ConsumerWidget {
  const GuidedAccountSubPicker({super.key, required this.metadata});

  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeKey = metadata['accountType'] as String? ?? '';
    final rawAccounts =
        (metadata['accounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final label = _labelForType(typeKey);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _botAvatar(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _bubbleDecor(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Which $label?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  rawAccounts.isEmpty
                      ? Text(
                          'No $label found. Please add one first.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: rawAccounts.map((a) {
                            final id = a['id'] as String;
                            final name = a['name'] as String;
                            return _AccountChip(
                              name: name,
                              typeKey: typeKey,
                              onTap: () => ref
                                  .read(assistantSessionProvider.notifier)
                                  .resolveGuidedAccountSub(id, name),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _labelForType(String key) {
    switch (key) {
      case 'bank':
        return 'Bank Account';
      case 'creditCard':
        return 'Credit Card';
      case 'wallet':
        return 'Wallet';
      case 'savings':
        return 'Savings Account';
      default:
        return 'account';
    }
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _botAvatar() => Container(
  width: 28,
  height: 28,
  margin: const EdgeInsets.only(right: 8, top: 2),
  decoration: BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.12),
    shape: BoxShape.circle,
  ),
  child: const Icon(
    Icons.smart_toy_rounded,
    size: 16,
    color: AppColors.primary,
  ),
);

BoxDecoration _bubbleDecor() => BoxDecoration(
  color: Colors.white,
  borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(4),
    bottomRight: Radius.circular(18),
  ),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ],
);

// ── Chips ─────────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.onTap});

  final AccountType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.name,
    required this.typeKey,
    required this.onTap,
  });

  final String name;
  final String typeKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
