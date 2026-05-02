import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/sms_transaction_service.dart';
import '../../core/services/sms_parser.dart';
import '../../core/services/transaction_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/account_matcher_service.dart';
import '../../core/theme/app_colors.dart';

/// Displays a banner above the recent transactions list whenever a new
/// SMS transaction is detected. Each card has Accept and Dismiss buttons.
class SmsTransactionBanner extends StatelessWidget {
  final SmsTransactionService smsService;
  final TransactionService transactionService;
  final AccountService accountService;

  const SmsTransactionBanner({
    super.key,
    required this.smsService,
    required this.transactionService,
    required this.accountService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: smsService,
      builder: (context, _) {
        final pending = smsService.pendingTransactions;
        if (pending.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section label
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sms_rounded,
                        size: 14,
                        color: Color(0xFF4ECDC4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pending.length} new SMS transaction${pending.length > 1 ? 's' : ''} detected',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // One card per pending transaction
              ...pending.map(
                (tx) => _SmsTransactionCard(
                  smsTx: tx,
                  smsService: smsService,
                  transactionService: transactionService,
                  accountService: accountService,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Individual card ───────────────────────────────────────────────────────────

class _SmsTransactionCard extends StatelessWidget {
  final SmsTransaction smsTx;
  final SmsTransactionService smsService;
  final TransactionService transactionService;
  final AccountService accountService;

  const _SmsTransactionCard({
    required this.smsTx,
    required this.smsService,
    required this.transactionService,
    required this.accountService,
  });

  String get _title {
    if (smsTx.vendor != null && smsTx.vendor!.isNotEmpty) return smsTx.vendor!;
    if (smsTx.bankName != null) return smsTx.bankName!;
    return smsTx.sender;
  }

  Future<void> _approve(BuildContext context) async {
    final txData = smsService.approveTransaction(smsTx);
    if (txData == null) return;

    final matchedAccount = AccountMatcherService.matchAccount(
      accounts: accountService.all,
      bankName: smsTx.bankName,
      accountUsed: smsTx.accountUsed,
    );

    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: txData['title'] as String,
      amount: txData['amount'] as double,
      type: TransactionType.expense,
      category: _categorize(txData['title'] as String),
      date: txData['date'] as DateTime,
      note: txData['note'] as String,
      accountId: matchedAccount?.id,
      source: txData['source'] as String,
      smsMessageId: txData['smsMessageId'] as String?,
      bankName: txData['bankName'] as String?,
    );

    await transactionService.addTransaction(newTx);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Added: ${newTx.title} — ₹${newTx.amount.toStringAsFixed(2)}',
          ),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _dismiss() => smsService.rejectTransaction(smsTx);

  TransactionCategory _categorize(String vendor) {
    final v = vendor.toLowerCase();
    if (v.contains('amazon') ||
        v.contains('flipkart') ||
        v.contains('shop') ||
        v.contains('store')) {
      return TransactionCategory.shopping;
    } else if (v.contains('swiggy') ||
        v.contains('zomato') ||
        v.contains('food') ||
        v.contains('restaurant')) {
      return TransactionCategory.food;
    } else if (v.contains('uber') ||
        v.contains('ola') ||
        v.contains('metro') ||
        v.contains('taxi')) {
      return TransactionCategory.transport;
    } else if (v.contains('electric') ||
        v.contains('water') ||
        v.contains('gas') ||
        v.contains('bill')) {
      return TransactionCategory.bills;
    } else if (v.contains('hospital') ||
        v.contains('doctor') ||
        v.contains('pharma') ||
        v.contains('medicine')) {
      return TransactionCategory.health;
    }
    return TransactionCategory.other;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateStr = smsTx.dateTime != null
        ? DateFormat('dd MMM, hh:mm a').format(smsTx.dateTime!)
        : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4ECDC4).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: icon + info + amount ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SMS icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sms_rounded,
                    color: Color(0xFF4ECDC4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Merchant + bank + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (smsTx.bankName != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4ECDC4,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                smsTx.bankName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount
                Text(
                  fmt.format(smsTx.amount ?? 0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────────
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Action buttons ─────────────────────────────────────────────
          Row(
            children: [
              // Dismiss
              Expanded(
                child: TextButton.icon(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Dismiss'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: Colors.grey.shade100),
              // Accept
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _approve(context),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'Add Expense',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2ECC71),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
