import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/models/credit_card_bill.dart';
import '../../core/models/transaction.dart';
import '../../core/services/account_service.dart';
import '../../core/services/bill_generation_service.dart';
import '../../core/services/credit_card_bill_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';
import 'add_account_sheet.dart';
import 'bill_generation_dialog.dart';
import 'bill_payment_sheet.dart';

class AccountDetailScreen extends StatefulWidget {
  final Account account;
  final AccountService accountService;
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final CreditCardBillService billService;
  final BillGenerationService billGenerationService;

  const AccountDetailScreen({
    super.key,
    required this.account,
    required this.accountService,
    required this.transactionService,
    required this.currencyService,
    required this.billService,
    required this.billGenerationService,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.accountService,
          widget.transactionService,
          widget.currencyService,
          widget.billService,
        ]),
        builder: (context, _) {
          // Always read the latest version of this account from the service
          final current = widget.accountService.all.firstWhere(
            (a) => a.id == widget.account.id,
            orElse: () => widget.account,
          );
          final fmt = widget.currencyService.formatter;
          final txs = widget.transactionService.transactionsForAccount(
            current.id,
          );

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero card header ──────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeroCard(context, current, fmt)),

              // ── Stats row (credit cards only) ─────────────────────────
              if (current.type == AccountType.creditCard &&
                  current.creditLimit != null)
                SliverToBoxAdapter(child: _buildCreditStats(current, fmt)),

              // ── Transactions section label ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRANSACTIONS'.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '${txs.length} total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Transaction list ──────────────────────────────────────
              if (txs.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyTransactions())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildTransactionTile(txs[i], current, fmt),
                      childCount: txs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context, Account acc, NumberFormat fmt) {
    final isCreditCard = acc.type == AccountType.creditCard;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: acc.type.gradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: acc.type.color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          final topPadding = MediaQuery.of(context).padding.top;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 4, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + edit row
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.edit_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 20,
                      ),
                      onPressed: () => showAddAccountSheet(
                        context,
                        widget.accountService,
                        editing: acc,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Account type icon + name
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(acc.type.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                acc.type.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              if (acc.lastFourDigits != null) ...[
                                Text(
                                  '  •  •••• ${acc.lastFourDigits}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                              if (acc.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Balance / outstanding
                Text(
                  isCreditCard
                      ? (acc.balance < 0 ? 'Credit Balance' : 'Outstanding')
                      : 'Balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  acc.balance < 0 && isCreditCard
                      ? fmt.format(acc.balance.abs())
                      : fmt.format(acc.balance),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: acc.balance < 0 && isCreditCard
                        ? const Color(0xFF2D9E6B) // Green for credit
                        : Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                // Credit limit line
                if (isCreditCard && acc.creditLimit != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Limit  ${fmt.format(acc.creditLimit!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],

                // Bill action button for credit cards
                if (isCreditCard) ...[
                  const SizedBox(height: 20),
                  _buildBillActionButton(context, acc, fmt),
                ],
              ],
            ),
          );
        }, // Builder
      ),
    );
  }

  // ── Bill action button ─────────────────────────────────────────────────────

  Widget _buildBillActionButton(
    BuildContext context,
    Account creditCardAccount,
    NumberFormat fmt,
  ) {
    // Check if bill date is set
    if (creditCardAccount.billDate == null) {
      return _buildGenerateBillButton(context, creditCardAccount);
    }

    // Check if a bill exists for this account
    final latestBill = widget.billService.getLatestBillForAccount(
      creditCardAccount.id,
    );

    if (latestBill == null) {
      return _buildGenerateBillButton(context, creditCardAccount);
    }

    // Check if bill is fully paid
    if (latestBill.status == BillStatus.paid) {
      // Bill is paid, check if it's time for next bill
      final now = DateTime.now();
      final nextBillDate = DateTime(
        latestBill.billDate.month == 12
            ? latestBill.billDate.year + 1
            : latestBill.billDate.year,
        latestBill.billDate.month == 12 ? 1 : latestBill.billDate.month + 1,
        creditCardAccount.billDate!,
      );

      if (now.day >= nextBillDate.day &&
          (now.month > latestBill.billDate.month ||
              now.year > latestBill.billDate.year)) {
        return _buildGenerateBillButton(context, creditCardAccount);
      }

      // Bill is paid and it's not time for next bill yet
      return const SizedBox.shrink();
    }

    // Bill exists and is not fully paid, show pay bill button
    return _buildPayBillButton(context, creditCardAccount, fmt);
  }

  Widget _buildGenerateBillButton(
    BuildContext context,
    Account creditCardAccount,
  ) {
    return GestureDetector(
      onTap: () => _generateBillManually(context, creditCardAccount),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Generate Bill',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayBillButton(
    BuildContext context,
    Account creditCardAccount,
    NumberFormat fmt,
  ) {
    return GestureDetector(
      onTap: () => _showPaymentSheet(context, creditCardAccount, fmt),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payment_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Pay Bill',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateBillManually(
    BuildContext context,
    Account creditCardAccount,
  ) async {
    // Show dialog to get bill amount
    showDialog(
      context: context,
      builder: (ctx) => BillGenerationDialog(
        creditCardAccount: creditCardAccount,
        defaultAmount: creditCardAccount.balance,
        currencyService: widget.currencyService,
        onBillGenerated: (amount) async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          try {
            // Generate bill with custom amount
            await widget.billGenerationService.generateBillWithAmount(
              creditCardAccount,
              amount,
            );

            // Refresh the screen
            if (mounted) {
              setState(() {});
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Bill generated successfully'),
                  backgroundColor: const Color(0xFF2D9E6B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Error generating bill: $e'),
                  backgroundColor: AppColors.accent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            }
          }
        },
      ),
    );
  }

  // ── Payment sheet handler ──────────────────────────────────────────────────

  void _showPaymentSheet(
    BuildContext context,
    Account creditCardAccount,
    NumberFormat fmt,
  ) {
    // For credit cards, the account.balance represents the outstanding balance
    final outstandingBalance = creditCardAccount.balance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillPaymentSheet(
        creditCardAccount: creditCardAccount,
        outstandingBalance: outstandingBalance,
        currencyService: widget.currencyService,
        onPaymentSubmitted: (amount, note) async {
          // Get the latest bill for this account
          final latestBill = widget.billService.getLatestBillForAccount(
            creditCardAccount.id,
          );

          if (latestBill == null) {
            _showSnackBar(
              context,
              'No bills found for this account',
              isError: true,
            );
            return;
          }

          try {
            // Record the payment
            await widget.billService.recordPayment(
              latestBill.id,
              amount,
              DateTime.now(),
              note,
            );

            // Update account balance (reduce outstanding)
            await widget.accountService.adjustBalance(
              creditCardAccount.id,
              -amount,
            );

            if (context.mounted) {
              _showSnackBar(
                context,
                'Payment of ${fmt.format(amount)} recorded successfully',
              );
            }
          } catch (e) {
            if (context.mounted) {
              _showSnackBar(
                context,
                'Error recording payment: $e',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.accent : const Color(0xFF2D9E6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Credit card stats row ─────────────────────────────────────────────────

  Widget _buildCreditStats(Account acc, NumberFormat fmt) {
    final utilization = acc.utilizationRatio ?? 0;
    final available = acc.availableCredit ?? 0;
    final utilizationColor = utilization >= 0.9
        ? const Color(0xFFFF5252)
        : utilization >= 0.7
        ? const Color(0xFFFFD740)
        : const Color(0xFF2D9E6B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
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
            Row(
              children: [
                Expanded(
                  child: _statItem(
                    'Available Credit',
                    fmt.format(available),
                    const Color(0xFF2D9E6B),
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.background),
                Expanded(
                  child: _statItem(
                    'Utilization',
                    '${(utilization * 100).toStringAsFixed(0)}%',
                    utilizationColor,
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: utilization,
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(utilizationColor),
              ),
            ),
            if (acc.billDate != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Bill due on the ${_ordinal(acc.billDate!)} of every month',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    String label,
    String value,
    Color valueColor, {
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ── Transaction tile ──────────────────────────────────────────────────────

  Widget _buildTransactionTile(Transaction tx, Account acc, NumberFormat fmt) {
    // Determine sign from the perspective of this account
    final isCredit = tx.isIncome || (tx.isTransfer && tx.toAccountId == acc.id);
    final sign = isCredit ? '+' : '-';
    final amountColor = isCredit
        ? const Color(0xFF2D9E6B)
        : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tx.category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(tx.category.icon, color: tx.category.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      tx.category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: AppColors.textLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy').format(tx.date),
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
            '$sign${fmt.format(tx.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty transactions ────────────────────────────────────────────────────

  Widget _buildEmptyTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Transactions on this account will appear here',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }
}
