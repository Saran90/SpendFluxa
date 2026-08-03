import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/account_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/budget_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/credit_card_bill_service.dart';
import '../../../core/services/tag_service.dart';
import '../../../core/services/transaction_service.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/assistant_providers.dart';
import 'assistant_screen.dart';

/// A [ListTile] that navigates to [AssistantScreen] from the Settings page.
///
/// Wraps the assistant feature in a [ProviderScope] override so the existing
/// app services are bridged into the Riverpod provider graph.
class AssistantSettingsTile extends StatelessWidget {
  const AssistantSettingsTile({
    super.key,
    required this.authService,
    required this.transactionService,
    required this.accountService,
    required this.budgetService,
    required this.categoryService,
    required this.tagService,
    required this.creditCardBillService,
  });

  final AuthService authService;
  final TransactionService transactionService;
  final AccountService accountService;
  final BudgetService budgetService;
  final CategoryService categoryService;
  final TagService tagService;
  final CreditCardBillService creditCardBillService;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: AppColors.primary,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          const Text(
            'Flux AI Assistant',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'BETA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      subtitle: const Text(
        'Chat with your personal finance advisor',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textLight,
      ),
      onTap: () => _openAssistant(context),
    );
  }

  void _openAssistant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            transactionServiceProvider.overrideWithValue(transactionService),
            accountServiceProvider.overrideWithValue(accountService),
            budgetServiceProvider.overrideWithValue(budgetService),
            categoryServiceProvider.overrideWithValue(categoryService),
            tagServiceProvider.overrideWithValue(tagService),
            creditCardBillServiceProvider.overrideWithValue(
              creditCardBillService,
            ),
          ],
          child: const AssistantScreen(),
        ),
      ),
    );
  }
}
