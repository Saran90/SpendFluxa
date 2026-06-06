import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/account.dart';
import '../../core/models/credit_card_bill.dart';
import '../../core/services/account_service.dart';
import '../../core/services/credit_card_bill_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/theme/app_colors.dart';

class CreditCardBillWidget extends StatelessWidget {
  final Account account;
  final CreditCardBillService billService;
  final AccountService accountService;
  final CurrencyService currencyService;

  const CreditCardBillWidget({
    super.key,
    required this.account,
    required this.billService,
    required this.accountService,
    required this.currencyService,
  });

  @override
  Widget build(BuildContext context) {
    if (account.type != AccountType.creditCard) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: billService,
      builder: (context, _) {
        final unpaidBill = billService.getUnpaidBillForCurrentMonth(account.id);
        final showGenerateBill = unpaidBill == null;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('MMMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: showGenerateBill
                      ? ElevatedButton.icon(
                          onPressed: () => _showGenerateBillDialog(context),
                          icon: const Icon(Icons.receipt_rounded, size: 18),
                          label: const Text('Generate Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () =>
                              _showPayBillDialog(context, unpaidBill),
                          icon: const Icon(Icons.payment_rounded, size: 18),
                          label: const Text('Pay Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D9E6B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showGenerateBillDialog(BuildContext context) async {
    final fmt = currencyService.formatter;
    final billAmountController = TextEditingController(
      text: account.balance.toStringAsFixed(2),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current outstanding: ${fmt.format(account.balance)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: billAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Bill Amount',
                border: OutlineInputBorder(),
                prefixText: '₹',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will generate a bill for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final billAmount = double.tryParse(billAmountController.text) ?? 0.0;
      if (billAmount > 0) {
        await billService.generateBill(account, billAmount);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill generated successfully'),
              backgroundColor: Color(0xFF2D9E6B),
            ),
          );
        }
      }
    }
  }

  Future<void> _showPayBillDialog(
    BuildContext context,
    CreditCardBill bill,
  ) async {
    final fmt = currencyService.formatter;
    String? selectedAccountId;

    final paymentAccounts = accountService.all
        .where(
          (a) =>
              a.type == AccountType.bank ||
              a.type == AccountType.wallet ||
              a.type == AccountType.savings,
        )
        .toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pay Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bill Amount',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                fmt.format(bill.billAmount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pay From',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedAccountId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select account',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No account (don\'t reduce balance)'),
                  ),
                  ...paymentAccounts.map(
                    (acc) => DropdownMenuItem<String>(
                      value: acc.id,
                      child: Row(
                        children: [
                          Icon(acc.type.icon, size: 18),
                          const SizedBox(width: 8),
                          Text('${acc.name} (${fmt.format(acc.balance)})'),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedAccountId = value);
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'This will reduce your credit card outstanding and the selected account balance',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D9E6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Pay Bill'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      await billService.payBill(bill, selectedAccountId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill paid successfully'),
            backgroundColor: Color(0xFF2D9E6B),
          ),
        );
      }
    }
  }
}
