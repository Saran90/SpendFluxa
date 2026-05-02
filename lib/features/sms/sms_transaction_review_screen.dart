import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/sms_transaction_service.dart';
import '../../core/services/sms_parser.dart';
import '../../core/services/transaction_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/account_matcher_service.dart';
import '../../core/models/transaction.dart';
import '../../core/theme/app_colors.dart';

/// Screen for reviewing and approving SMS-detected transactions
class SmsTransactionReviewScreen extends StatefulWidget {
  final SmsTransactionService smsService;
  final TransactionService transactionService;
  final AccountService accountService;

  const SmsTransactionReviewScreen({
    super.key,
    required this.smsService,
    required this.transactionService,
    required this.accountService,
  });

  @override
  State<SmsTransactionReviewScreen> createState() =>
      _SmsTransactionReviewScreenState();
}

class _SmsTransactionReviewScreenState
    extends State<SmsTransactionReviewScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  @override
  void initState() {
    super.initState();
    // Only scan if there are no pending transactions
    // This handles the case where user navigates directly without scanning first
    if (widget.smsService.pendingTransactions.isEmpty &&
        !widget.smsService.isLoading) {
      widget.smsService.scanSmsMessages();
    }
  }

  Future<void> _approveTransaction(SmsTransaction smsTx) async {
    // Get transaction data from SMS
    final txData = widget.smsService.approveTransaction(smsTx);

    if (txData == null) return;

    // Match account automatically
    final matchedAccount = AccountMatcherService.matchAccount(
      accounts: widget.accountService.all,
      bankName: smsTx.bankName,
      accountUsed: smsTx.accountUsed,
    );

    // Get match confidence for logging
    final confidence = matchedAccount != null
        ? AccountMatcherService.getMatchConfidence(
            account: matchedAccount,
            bankName: smsTx.bankName,
            accountUsed: smsTx.accountUsed,
          )
        : 0.0;

    debugPrint(
      '[SMS] Matched account: ${matchedAccount?.name ?? 'None'} '
      '(confidence: ${(confidence * 100).toStringAsFixed(0)}%)',
    );

    // Create a new transaction
    final newTx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: txData['title'] as String,
      amount: txData['amount'] as double,
      type: TransactionType.expense,
      category: _categorizeVendor(txData['title'] as String),
      date: txData['date'] as DateTime,
      note: txData['note'] as String,
      accountId: matchedAccount?.id, // Auto-assigned account
      source: txData['source'] as String,
      smsMessageId: txData['smsMessageId'] as String?,
      bankName: txData['bankName'] as String?,
    );

    // Add to transaction service
    await widget.transactionService.addTransaction(newTx);

    if (mounted) {
      final accountInfo = matchedAccount != null
          ? ' • ${matchedAccount.name}'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added: ${newTx.title} - ${_currencyFormat.format(newTx.amount)}$accountInfo',
          ),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    }
  }

  void _rejectTransaction(SmsTransaction smsTx) {
    widget.smsService.rejectTransaction(smsTx);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction dismissed'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  TransactionCategory _categorizeVendor(String vendor) {
    final vendorLower = vendor.toLowerCase();

    // Simple keyword-based categorization
    if (vendorLower.contains('amazon') ||
        vendorLower.contains('flipkart') ||
        vendorLower.contains('shop') ||
        vendorLower.contains('store')) {
      return TransactionCategory.shopping;
    } else if (vendorLower.contains('food') ||
        vendorLower.contains('restaurant') ||
        vendorLower.contains('swiggy') ||
        vendorLower.contains('zomato')) {
      return TransactionCategory.food;
    } else if (vendorLower.contains('uber') ||
        vendorLower.contains('ola') ||
        vendorLower.contains('taxi') ||
        vendorLower.contains('metro')) {
      return TransactionCategory.transport;
    } else if (vendorLower.contains('electric') ||
        vendorLower.contains('water') ||
        vendorLower.contains('gas') ||
        vendorLower.contains('bill')) {
      return TransactionCategory.bills;
    } else if (vendorLower.contains('hospital') ||
        vendorLower.contains('doctor') ||
        vendorLower.contains('medicine') ||
        vendorLower.contains('pharma')) {
      return TransactionCategory.health;
    } else {
      return TransactionCategory.other;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SMS Transactions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.smsService,
            builder: (context, _) {
              if (widget.smsService.pendingCount > 0) {
                return TextButton(
                  onPressed: () => widget.smsService.clearPendingTransactions(),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Color(0xFFFF6B6B)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.smsService,
        builder: (context, _) {
          if (widget.smsService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.smsService.pendingTransactions.isEmpty) {
            return _buildEmptyState();
          }

          return _buildTransactionList();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Color(0xFF4ECDC4),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Caught Up!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No new SMS transactions to review.\nScan again later for new transactions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => widget.smsService.scanSmsMessages(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4ECDC4),
                side: const BorderSide(color: Color(0xFF4ECDC4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Column(
      children: [
        _buildSummaryHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.smsService.pendingTransactions.length,
            itemBuilder: (context, index) {
              final smsTx = widget.smsService.pendingTransactions[index];
              return _buildTransactionCard(smsTx);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    final total = widget.smsService.pendingTransactions.fold<double>(
      0,
      (sum, tx) => sum + (tx.amount ?? 0),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Pending',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(total),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.smsService.pendingCount} transactions',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(SmsTransaction smsTx) {
    // Match account for preview
    final matchedAccount = AccountMatcherService.matchAccount(
      accounts: widget.accountService.all,
      bankName: smsTx.bankName,
      accountUsed: smsTx.accountUsed,
    );

    final confidence = matchedAccount != null
        ? AccountMatcherService.getMatchConfidence(
            account: matchedAccount,
            bankName: smsTx.bankName,
            accountUsed: smsTx.accountUsed,
          )
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            smsTx.vendor ?? 'Unknown Merchant',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4ECDC4,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  smsTx.bankName ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4ECDC4),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (matchedAccount != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: confidence >= 0.6
                                        ? const Color(
                                            0xFF2ECC71,
                                          ).withValues(alpha: 0.1)
                                        : const Color(
                                            0xFFFF9800,
                                          ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet,
                                        size: 12,
                                        color: confidence >= 0.6
                                            ? const Color(0xFF2ECC71)
                                            : const Color(0xFFFF9800),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        matchedAccount.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: confidence >= 0.6
                                              ? const Color(0xFF2ECC71)
                                              : const Color(0xFFFF9800),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (smsTx.dateTime != null)
                                Text(
                                  _dateFormat.format(smsTx.dateTime!),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(smsTx.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    smsTx.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _rejectTransaction(smsTx),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close, size: 20),
                      SizedBox(width: 4),
                      Text('Dismiss'),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
              Expanded(
                child: TextButton(
                  onPressed: () => _approveTransaction(smsTx),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2ECC71),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 20),
                      SizedBox(width: 4),
                      Text('Add to Expenses'),
                    ],
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
