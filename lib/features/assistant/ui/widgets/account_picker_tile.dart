import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/account.dart';
import '../../../../core/services/account_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../providers/assistant_providers.dart';
import '../../providers/assistant_session_notifier.dart';

/// Two-step in-chat account picker.
///
/// Step 1: show account type chips (Bank, Credit Card, Wallet, Cash, Savings).
/// Step 2: show accounts of the chosen type so the user can pick one.
///
/// On selection, calls [AssistantSessionNotifier.resolveAccountSelection].
class AccountPickerTile extends ConsumerStatefulWidget {
  const AccountPickerTile({super.key, required this.message});
  final ChatMessage message;

  @override
  ConsumerState<AccountPickerTile> createState() => _AccountPickerTileState();
}

class _AccountPickerTileState extends ConsumerState<AccountPickerTile> {
  AccountType? _selectedType;

  @override
  void initState() {
    super.initState();
    // If message type is accountPicker (preselected type), skip type step
    final meta = widget.message.metadata;
    if (widget.message.messageType == ChatMessageType.accountPicker &&
        meta != null &&
        meta['accountType'] != null) {
      final typeName = meta['accountType'] as String;
      _selectedType = AccountType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => AccountType.creditCard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountService = ref.read(accountServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot avatar
          Container(
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
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
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
              ),
              child: _selectedType == null
                  ? _TypeStep(
                      accountService: accountService,
                      onSelected: (type) =>
                          setState(() => _selectedType = type),
                      onSkip: () => _resolve(null),
                    )
                  : _AccountStep(
                      accountService: accountService,
                      type: _selectedType!,
                      onSelected: (id) => _resolve(id),
                      onBack: () => setState(() => _selectedType = null),
                    ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _resolve(String? accountId) {
    ref
        .read(assistantSessionProvider.notifier)
        .resolveAccountSelection(accountId);
  }
}

// ── Step 1: account type ──────────────────────────────────────────────────────

class _TypeStep extends StatelessWidget {
  const _TypeStep({
    required this.accountService,
    required this.onSelected,
    required this.onSkip,
  });

  final AccountService accountService;
  final void Function(AccountType) onSelected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Only show types that have at least one account.
    final available = AccountType.values.where((t) {
      return accountService.all.any((a) => a.type == t);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Which payment method did you use?',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available
              .map((t) => _TypeChip(type: t, onTap: onSelected))
              .toList(),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onSkip,
          child: const Text(
            'Skip',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.onTap});
  final AccountType type;
  final void Function(AccountType) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: type.color.withValues(alpha: 0.10),
          border: Border.all(color: type.color.withValues(alpha: 0.40)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 16, color: type.color),
            const SizedBox(width: 6),
            Text(
              type.label,
              style: TextStyle(
                fontSize: 13,
                color: type.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: specific account ──────────────────────────────────────────────────

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.accountService,
    required this.type,
    required this.onSelected,
    required this.onBack,
  });

  final AccountService accountService;
  final AccountType type;
  final void Function(String) onSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final accounts = accountService.all.where((a) => a.type == type).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Select ${type.label}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...accounts.map(
          (a) => _AccountRow(account: a, onTap: () => onSelected(a.id)),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onTap});
  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFECF0F1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: account.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(account.type.icon, size: 18, color: account.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (account.lastFourDigits != null)
                    Text(
                      '•••• ${account.lastFourDigits}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textLight,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
