import 'package:flutter/material.dart';
import '../../core/models/account.dart';
import '../../core/models/credit_card_bill.dart';
import '../../core/services/account_service.dart';
import '../../core/services/credit_card_bill_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/theme/app_colors.dart';
import 'bill_generation_sheet.dart';
import 'bill_payment_sheet.dart';

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
                    const Text(
                      'Monthly Bill',
                      style: TextStyle(
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: BillGenerationSheet(
          creditCardAccount: account,
          currencyService: currencyService,
          onBillGenerated: (billAmount) async {
            await billService.generateBill(account, billAmount);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bill generated successfully'),
                  backgroundColor: Color(0xFF2D9E6B),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _showPayBillDialog(
    BuildContext context,
    CreditCardBill bill,
  ) async {
    final paymentAccounts = accountService.all
        .where(
          (a) =>
              a.type == AccountType.bank ||
              a.type == AccountType.wallet ||
              a.type == AccountType.savings,
        )
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BillPaymentSheet(
        creditCardAccount: account,
        billAmount: bill.billAmount,
        payableAccounts: paymentAccounts,
        currencyService: currencyService,
        onPaymentSubmitted: (fromAccountId) async {
          await billService.payBill(bill, fromAccountId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bill paid successfully'),
                backgroundColor: Color(0xFF2D9E6B),
              ),
            );
          }
        },
      ),
    );
  }
}
