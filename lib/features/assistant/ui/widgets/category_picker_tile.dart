import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/transaction.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../providers/assistant_providers.dart';

/// In-chat category picker.
///
/// Shows the best-matching categories as chips so the user can confirm or
/// correct the auto-detected category before the transaction is created.
/// The suggested (best-match) category is visually highlighted.
/// A "View all" button expands to show every category for the transaction type.
class CategoryPickerTile extends ConsumerStatefulWidget {
  const CategoryPickerTile({super.key, required this.message});
  final ChatMessage message;

  @override
  ConsumerState<CategoryPickerTile> createState() => _CategoryPickerTileState();
}

class _CategoryPickerTileState extends ConsumerState<CategoryPickerTile> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final meta = widget.message.metadata ?? {};
    final candidateNames =
        (meta['candidates'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final suggestedName = meta['suggested'] as String?;
    final typeStr = meta['transactionType'] as String? ?? 'expense';

    final transactionType = TransactionType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => TransactionType.expense,
    );

    // Resolve suggested candidates
    final candidates = candidateNames
        .map(
          (name) => TransactionCategory.values
              .where((c) => c.name == name)
              .firstOrNull,
        )
        .whereType<TransactionCategory>()
        .toList();

    // All categories for this type (for the expanded view)
    final allForType = _categoriesForType(transactionType);

    if (candidates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    'Which category fits best?',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Suggested candidates
                  if (!_showAll) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: candidates.map((cat) {
                        return _CategoryChip(
                          category: cat,
                          isSuggested: cat.name == suggestedName,
                          onTap: () => _resolve(cat.name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showAll = true),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.expand_more_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View all categories',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // All categories expanded view
                  if (_showAll) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allForType.map((cat) {
                        return _CategoryChip(
                          category: cat,
                          isSuggested: cat.name == suggestedName,
                          onTap: () => _resolve(cat.name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _showAll = false),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.expand_less_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Show less',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _resolve(String? categoryName) {
    ref
        .read(assistantSessionProvider.notifier)
        .resolveCategorySelection(categoryName);
  }

  List<TransactionCategory> _categoriesForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return [
          TransactionCategory.salary,
          TransactionCategory.freelance,
          TransactionCategory.investment,
          TransactionCategory.gift,
          TransactionCategory.cashback,
        ];
      case TransactionType.transfer:
        return [
          TransactionCategory.savings,
          TransactionCategory.childEducation,
          TransactionCategory.vacation,
          TransactionCategory.emergencyFund,
          TransactionCategory.transferInvestment,
          TransactionCategory.houseDownPayment,
          TransactionCategory.retirement,
          TransactionCategory.transferOther,
        ];
      case TransactionType.expense:
        return [
          TransactionCategory.food,
          TransactionCategory.grocery,
          TransactionCategory.vegetables,
          TransactionCategory.bakery,
          TransactionCategory.drinksAndSnacks,
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
          TransactionCategory.expenseInvestment,
          TransactionCategory.other,
        ];
    }
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSuggested,
    required this.onTap,
  });

  final TransactionCategory category;
  final bool isSuggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSuggested ? color.withValues(alpha: 0.15) : Colors.white,
          border: Border.all(
            color: isSuggested ? color : color.withValues(alpha: 0.35),
            width: isSuggested ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 13,
                color: isSuggested ? color : AppColors.textPrimary,
                fontWeight: isSuggested ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (isSuggested) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, size: 13, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
