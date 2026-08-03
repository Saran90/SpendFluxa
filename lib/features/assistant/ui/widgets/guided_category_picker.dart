import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/assistant_providers.dart';

/// Inline category quick-select chips for the guided transaction flow.
class GuidedCategoryPicker extends ConsumerWidget {
  const GuidedCategoryPicker({super.key});

  static const _expenseCategories = [
    TransactionCategory.food,
    TransactionCategory.grocery,
    TransactionCategory.vegetables,
    TransactionCategory.transport,
    TransactionCategory.fuel,
    TransactionCategory.shopping,
    TransactionCategory.entertainment,
    TransactionCategory.health,
    TransactionCategory.utilities,
    TransactionCategory.bills,
    TransactionCategory.rent,
    TransactionCategory.education,
    TransactionCategory.insurance,
    TransactionCategory.other,
  ];

  static const _incomeCategories = [
    TransactionCategory.salary,
    TransactionCategory.freelance,
    TransactionCategory.investment,
    TransactionCategory.gift,
    TransactionCategory.cashback,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show both sets so the picker works for both flow types
    final categories = [..._expenseCategories, ..._incomeCategories];

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Which category?',
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
                    children: categories.map((cat) {
                      return _CategoryChip(
                        category: cat,
                        onTap: () => ref
                            .read(assistantSessionProvider.notifier)
                            .resolveGuidedCategory(cat.name, cat.label),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final TransactionCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              category.label,
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
