import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/services/currency_service.dart';
import '../../core/theme/app_colors.dart';

/// Bottom sheet for recording credit card bill payments.
///
/// On submit, calls [onPaymentSubmitted] with:
///   - amount: the payment amount
///   - fromAccountId: the bank/wallet account the money comes from (nullable = cash/untracked)
///   - note: optional note
class BillPaymentSheet extends StatefulWidget {
  final Account creditCardAccount;
  final double outstandingBalance;
  final double? billAmount;
  final List<Account> payableAccounts; // non-CC accounts to pay from
  final CurrencyService currencyService;
  final Function(double amount, String? fromAccountId, String? note)
  onPaymentSubmitted;

  const BillPaymentSheet({
    super.key,
    required this.creditCardAccount,
    required this.outstandingBalance,
    required this.payableAccounts,
    required this.currencyService,
    required this.onPaymentSubmitted,
    this.billAmount,
  });

  @override
  State<BillPaymentSheet> createState() => _BillPaymentSheetState();
}

class _BillPaymentSheetState extends State<BillPaymentSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  Account? _selectedFromAccount;
  bool _isSubmitting = false;
  String? _quickFill; // 'bill' | 'outstanding' | null

  @override
  void initState() {
    super.initState();
    final initial = widget.billAmount ?? widget.outstandingBalance;
    _amountController = TextEditingController(
      text: initial > 0 ? initial.toStringAsFixed(2) : '',
    );
    _quickFill = widget.billAmount != null ? 'bill' : 'outstanding';
    _noteController = TextEditingController();
    _selectedDate = DateTime.now();
    // Default to first payable account (usually the default bank account)
    _selectedFromAccount = widget.payableAccounts.isNotEmpty
        ? widget.payableAccounts.first
        : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyQuickFill(String type) {
    setState(() {
      if (_quickFill == type) {
        _quickFill = null;
        _amountController.clear();
      } else {
        _quickFill = type;
        final value = type == 'bill'
            ? widget.billAmount!
            : widget.outstandingBalance;
        _amountController.text = value.toStringAsFixed(2);
      }
    });
  }

  Future<void> _submitPayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Please enter payment amount');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onPaymentSubmitted(
        amount,
        _selectedFromAccount?.id,
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccess('Payment recorded successfully');
      }
    } catch (e) {
      _showError('Error recording payment: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2D9E6B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fmt = widget.currencyService.formatter;
    final symbol = widget.currencyService.symbol;
    final hasBill = widget.billAmount != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                children: [
                  const Text(
                    'Pay Bill',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.creditCardAccount.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Bill info card ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    if (hasBill) ...[
                      _infoRow(
                        label: 'Bill Amount',
                        value: fmt.format(widget.billAmount!),
                        valueColor: AppColors.textPrimary,
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.primary,
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.textSecondary.withValues(alpha: 0.12),
                      ),
                    ],
                    _infoRow(
                      label: widget.outstandingBalance < 0
                          ? 'Credit Balance'
                          : 'Total Outstanding',
                      value: fmt.format(widget.outstandingBalance.abs()),
                      valueColor: widget.outstandingBalance < 0
                          ? const Color(0xFF2D9E6B)
                          : AppColors.textPrimary,
                      icon: widget.outstandingBalance < 0
                          ? Icons.savings_rounded
                          : Icons.account_balance_wallet_rounded,
                      iconColor: widget.outstandingBalance < 0
                          ? const Color(0xFF2D9E6B)
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Pay from account ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pay From',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.payableAccounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No bank/wallet accounts found',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.payableAccounts.length,
                        separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final acc = widget.payableAccounts[i];
                          final isSelected = _selectedFromAccount?.id == acc.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFromAccount = acc),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? acc.type.color.withValues(alpha: 0.1)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? acc.type.color
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.2,
                                        ),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: acc.type.color.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      acc.type.icon,
                                      size: 16,
                                      color: acc.type.color,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        acc.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? acc.type.color
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        widget.currencyService.formatter.format(
                                          acc.balance,
                                        ),
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
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Payment amount ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Amount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            symbol,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            onChanged: (_) {
                              if (_quickFill != null) {
                                setState(() => _quickFill = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Quick-fill chips
                  Row(
                    children: [
                      if (hasBill)
                        Expanded(
                          child: _quickFillChip(
                            label: 'Bill Amount',
                            value: fmt.format(widget.billAmount!),
                            type: 'bill',
                            color: AppColors.primary,
                          ),
                        ),
                      if (hasBill) const SizedBox(width: 10),
                      Expanded(
                        child: _quickFillChip(
                          label: 'Full Outstanding',
                          value: fmt.format(widget.outstandingBalance.abs()),
                          type: 'outstanding',
                          color: const Color(0xFF607D8B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Payment date ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Note ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Note (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add a note about this payment...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _isSubmitting ? null : _submitPayment,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isSubmitting
                          ? [
                              AppColors.primary.withValues(alpha: 0.5),
                              AppColors.primary.withValues(alpha: 0.5),
                            ]
                          : [AppColors.primary, const Color(0xFF1A7A50)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isSubmitting ? 'Recording...' : 'Record Payment',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFillChip({
    required String label,
    required String value,
    required String type,
    required Color color,
  }) {
    final isActive = _quickFill == type;
    return GestureDetector(
      onTap: () => _applyQuickFill(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? color
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? color : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
