import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'walkthrough_data.dart';

class FeatureWalkthroughScreen extends StatefulWidget {
  final FeatureType featureType;

  const FeatureWalkthroughScreen({super.key, required this.featureType});

  @override
  State<FeatureWalkthroughScreen> createState() =>
      _FeatureWalkthroughScreenState();
}

class _FeatureWalkthroughScreenState extends State<FeatureWalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<WalkthroughStep> get _steps {
    switch (widget.featureType) {
      case FeatureType.addTransaction:
        return _addTransactionSteps;
      case FeatureType.accounts:
        return _accountsSteps;
      case FeatureType.accountTransfer:
        return _accountTransferSteps;
      case FeatureType.recurring:
        return _recurringSteps;
      case FeatureType.reminders:
        return _remindersSteps;
      case FeatureType.creditCard:
        return _creditCardSteps;
      case FeatureType.creditCardBills:
        return _creditCardBillSteps;
      case FeatureType.tags:
        return _tagsSteps;
      case FeatureType.budgets:
        return _budgetsSteps;
      case FeatureType.excludeExpense:
        return _excludeExpenseSteps;
      case FeatureType.backup:
        return _backupSteps;
      case FeatureType.customCategories:
        return _customCategoriesSteps;
      case FeatureType.analytics:
        return _analyticsSteps;
    }
  }

  String get _title {
    switch (widget.featureType) {
      case FeatureType.addTransaction:
        return 'Adding Transactions';
      case FeatureType.accounts:
        return 'Managing Accounts';
      case FeatureType.accountTransfer:
        return 'Account Transfers';
      case FeatureType.recurring:
        return 'Recurring Transactions';
      case FeatureType.reminders:
        return 'Reminders';
      case FeatureType.creditCard:
        return 'Credit Cards & EMI';
      case FeatureType.creditCardBills:
        return 'Credit Card Bills';
      case FeatureType.tags:
        return 'Tags';
      case FeatureType.budgets:
        return 'Budgets';
      case FeatureType.excludeExpense:
        return 'Exclude from Expenses';
      case FeatureType.backup:
        return 'Backup & Restore';
      case FeatureType.customCategories:
        return 'Custom Categories';
      case FeatureType.analytics:
        return 'Analytics';
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: steps.length,
              itemBuilder: (context, index) {
                return _buildStepPage(steps[index], index + 1, steps.length);
              },
            ),
          ),
          _buildBottomNavigation(steps.length),
        ],
      ),
    );
  }

  Widget _buildStepPage(WalkthroughStep step, int stepNumber, int totalSteps) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step $stepNumber of $totalSteps',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Visual illustration
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: step.color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(step.icon, size: 80, color: step.color),
                const SizedBox(height: 16),
                if (step.visualHint != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      step.visualHint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: step.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Tips (if any)
          if (step.tips.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE69C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        size: 18,
                        color: Color(0xFFFF9800),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF856404),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...step.tips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'â€¢ ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF856404),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(int totalSteps) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalSteps,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.textLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Navigation buttons
            Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < totalSteps - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < totalSteps - 1 ? 'Next' : 'Done',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WalkthroughStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? visualHint;
  final List<String> tips;

  const WalkthroughStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.visualHint,
    this.tips = const [],
  });
}

// â”€â”€ Walkthrough content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// Adding Transactions
final _addTransactionSteps = [
  const WalkthroughStep(
    title: 'Tap the + Button',
    description:
        'On the home screen, tap the floating action button (+ icon) at the bottom centre to start adding a new transaction.',
    icon: Icons.add_circle_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Tap the + button',
    tips: [
      'The button is always visible on the home screen',
      'You can add transactions from anywhere in the app',
    ],
  ),
  const WalkthroughStep(
    title: 'Choose Transaction Type',
    description:
        'Select whether this is an Expense, Income, or Transfer. The screen colour changes to match:\n\nâ€¢ Red for Expenses\nâ€¢ Green for Income\nâ€¢ Teal for Transfers',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Expense â€¢ Income â€¢ Transfer',
    tips: [
      'Most transactions are expenses',
      'Use Transfer to move money between accounts',
    ],
  ),
  const WalkthroughStep(
    title: 'Enter Amount â€” with a Calculator',
    description:
        'Type the amount directly, or tap the calculator icon next to the amount field to open the built-in calculator. It supports +, âˆ’, Ã—, Ã· and shows a live result as you type.',
    icon: Icons.calculate_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'â‚¹ 1,500  ðŸ–©',
    tips: [
      'Tap the calculator icon beside the amount field',
      'Tap "Use Result" to transfer the answer to the amount field',
    ],
  ),
  const WalkthroughStep(
    title: 'Add Title & Category',
    description:
        'Give your transaction a name (optional) and select a category. Both built-in and your own custom categories appear in the picker.',
    icon: Icons.category_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Grocery Shopping',
    tips: [
      'If you leave the title blank, the category name is used',
      'Custom categories are shown with a coloured badge',
    ],
  ),
  const WalkthroughStep(
    title: 'Select Date & Account',
    description:
        'Choose the transaction date â€” you can pick today, any past date, or even a future date. Select the account the money belongs to.',
    icon: Icons.calendar_today_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Today â€¢ Future dates allowed',
    tips: [
      'Future-dated transactions appear in your list on that date',
      'Useful for recording upcoming bills in advance',
    ],
  ),
  const WalkthroughStep(
    title: 'Save Transaction',
    description:
        'Tap "Save" to record the transaction. It appears in your list instantly and your account balance is updated.',
    icon: Icons.check_circle_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Transaction Saved!',
    tips: [
      'Tap any transaction to edit it later',
      'Swipe left on a transaction to delete it',
    ],
  ),
];

// Account Transfers
final _accountTransferSteps = [
  const WalkthroughStep(
    title: 'What is an Account Transfer?',
    description:
        'A transfer moves money from one account to another â€” for example sending money to a savings account, topping up a wallet, or making an investment.',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Bank â†’ Savings',
    tips: [
      'Transfers debit the source account and credit the destination',
      'The full amount is reflected on both accounts immediately',
    ],
  ),
  const WalkthroughStep(
    title: 'Choose Transfer Category',
    description:
        'When the Transfer type is selected, a set of purpose-driven categories appears:\n\nâ€¢ Savings\nâ€¢ Child Education\nâ€¢ Vacation\nâ€¢ Emergency Fund\nâ€¢ Investment\nâ€¢ House Down Payment\nâ€¢ Retirement\nâ€¢ Other',
    icon: Icons.category_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Pick a Purpose',
    tips: [
      'Choosing a category helps you understand why money was moved',
      'You can also create custom transfer categories',
    ],
  ),
  const WalkthroughStep(
    title: 'Select From & To Accounts',
    description:
        'After choosing Transfer, two account selectors appear â€” "From" (source) and "To" (destination). Both must be different accounts.',
    icon: Icons.compare_arrows_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'From: Bank  â†’  To: Savings',
    tips: [
      'You cannot transfer to the same account',
      'Credit cards can be either source or destination',
    ],
  ),
  const WalkthroughStep(
    title: 'Transfer Appears in Transaction List',
    description:
        'Transfers are shown with a teal border and arrow badge in the transaction list so they are easy to spot. The amount is displayed in teal without a +/âˆ’ sign.',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'â†”  Teal border',
    tips: [
      'Transfers are not counted in expense or income totals',
      'They are still visible in account transaction history',
    ],
  ),
  const WalkthroughStep(
    title: 'Convert to Recurring Transfer',
    description:
        'If you regularly move a fixed amount (e.g. monthly savings), edit the transfer and enable the Recurring toggle. The original entry is kept as-is, and a new recurring series starts from next month.',
    icon: Icons.repeat_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Original kept + New series',
    tips: [
      'The existing transfer is never deleted when converting to recurring',
      'The recurring template starts from the 1st of next month',
    ],
  ),
];

// Recurring Transactions
final _recurringSteps = [
  const WalkthroughStep(
    title: 'What are Recurring Transactions?',
    description:
        'Recurring transactions are regular payments set up once â€” like subscriptions, rent, or salary â€” so you do not have to add them manually each period.',
    icon: Icons.repeat_rounded,
    color: AppColors.primary,
    visualHint: 'Netflix â€¢ Rent â€¢ Salary',
    tips: [
      'Perfect for monthly bills and subscriptions',
      'Supports daily, weekly, monthly and yearly frequencies',
    ],
  ),
  const WalkthroughStep(
    title: 'Create a Recurring Transaction',
    description:
        'When adding a transaction, enable the "Recurring" toggle. Choose a frequency (daily, weekly, monthly or yearly) and optionally set an end date.',
    icon: Icons.toggle_on_rounded,
    color: AppColors.primary,
    visualHint: 'Enable Recurring Toggle',
    tips: [
      'Monthly is the most common frequency',
      'Leave end date blank for open-ended recurring entries',
    ],
  ),
  const WalkthroughStep(
    title: 'Convert an Existing Transaction',
    description:
        'Already have a one-off transaction you want to make recurring? Edit it and turn on the Recurring toggle. The original transaction is kept unchanged, and a new recurring template is created starting from the 1st of next month.',
    icon: Icons.edit_rounded,
    color: AppColors.primary,
    visualHint: 'Original kept â€¢ Series from next month',
    tips: [
      'This works for all types â€” expenses, income and transfers',
      'No balance adjustments are made to the original entry',
    ],
  ),
  const WalkthroughStep(
    title: 'Confirmation Banner',
    description:
        'On the due date, a banner appears on your home screen asking you to confirm the transaction. This gives you full control over each occurrence.',
    icon: Icons.notification_important_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'DUE TODAY',
    tips: [
      'Tap "Record" to create the transaction for that period',
      'Tap "Not Now" to skip without deleting the template',
    ],
  ),
  const WalkthroughStep(
    title: 'Managing Recurring Transactions',
    description:
        'View all recurring transactions in the "Recurring Transactions" section on the home screen. Tap any card to edit or delete it.',
    icon: Icons.list_alt_rounded,
    color: AppColors.primary,
    visualHint: 'Tap to Edit',
    tips: [
      'Editing the template only affects future occurrences',
      'Past confirmed transactions remain unchanged',
    ],
  ),
];

// Reminders
final _remindersSteps = [
  const WalkthroughStep(
    title: 'Set Up Reminders',
    description:
        'Reminders notify you before a recurring transaction is due. Tap a recurring transaction, then tap "Manage Reminders" to set them up.',
    icon: Icons.notifications_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Manage Reminders',
    tips: [
      'Reminders only work for recurring transactions',
      'You can set multiple reminders for one transaction',
    ],
  ),
  const WalkthroughStep(
    title: 'Choose Reminder Timing',
    description:
        'Select when you want to be reminded:\n\nâ€¢ Same day\nâ€¢ 1 day before\nâ€¢ 2 days before\nâ€¢ 3 days before\nâ€¢ 1 week before\n\nAlso choose the time of day.',
    icon: Icons.access_time_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: '2 days before at 9:00 AM',
    tips: [
      'Set reminders a few days early so you can plan',
      'Choose a time when you usually check your phone',
    ],
  ),
  const WalkthroughStep(
    title: 'Reminder Banner',
    description:
        'When a reminder is due, a banner appears on your home screen showing the upcoming transaction details and how many days until it is due.',
    icon: Icons.campaign_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'IN 2 DAYS',
    tips: [
      'The banner shows the transaction amount and date',
      'Dismiss it once you have noted the upcoming payment',
    ],
  ),
  const WalkthroughStep(
    title: 'Enable / Disable Reminders',
    description:
        'Toggle reminders on or off anytime. Disabled reminders won\'t show banners but remain saved for future use.',
    icon: Icons.toggle_off_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Toggle On / Off',
    tips: [
      'Useful when you are on vacation',
      'Re-enable them when you return',
    ],
  ),
];

// Credit Cards & EMI
final _creditCardSteps = [
  const WalkthroughStep(
    title: 'Add a Credit Card Account',
    description:
        'Go to Profile â†’ Accounts â†’ Add Account. Select "Credit Card" and enter your card details including the credit limit, bill date, and last four digits.',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Credit Card Account',
    tips: [
      'Enter your total credit limit for accurate utilisation tracking',
      'The bill date is used for generating monthly bills',
    ],
  ),
  const WalkthroughStep(
    title: 'Track Credit Card Spending',
    description:
        'When adding an expense, select your credit card as the account. Credit card transactions are automatically marked as non-expense but monthly, so they appear in your records without double-counting.',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: '45% Utilised',
    tips: [
      'Keep utilisation below 30% for healthy credit',
      'The app shows a progress bar and outstanding balance per card',
    ],
  ),
  const WalkthroughStep(
    title: 'EMI Transactions',
    description:
        'For purchases with EMI, enable the "EMI" toggle when adding a transaction. Enter the interest rate and duration in months â€” the app calculates your monthly instalment automatically.',
    icon: Icons.payments_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: '12 months @ 12% p.a.',
    tips: [
      'EMI transactions are excluded from expense totals',
      'Each instalment appears on its due date',
    ],
  ),
  const WalkthroughStep(
    title: 'How EMI Works',
    description:
        'The app creates a parent transaction for the full purchase amount and individual monthly instalments. This lets you track both the total debt and the monthly payment schedule.',
    icon: Icons.account_tree_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Parent + Instalments',
    tips: [
      'The parent transaction shows the total amount',
      'Monthly instalments appear on their scheduled dates',
    ],
  ),
];

// Credit Card Bills
final _creditCardBillSteps = [
  const WalkthroughStep(
    title: 'What is a Credit Card Bill?',
    description:
        'At the end of each billing cycle, your credit card issuer generates a bill for all transactions made that month. SpendFlux lets you generate and pay this bill within the app.',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Monthly Bill',
    tips: [
      'The bill amount is based on your outstanding balance',
      'You can pay the full bill or a partial amount',
    ],
  ),
  const WalkthroughStep(
    title: 'Generate a Bill',
    description:
        'Open the credit card account detail page. Tap "Generate Bill". The outstanding balance is automatically pre-filled as the bill amount. You can change it if needed.',
    icon: Icons.note_add_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Outstanding â†’ Bill Amount',
    tips: [
      'The current outstanding amount is shown in the dialog',
      'You can generate a bill for a different amount if you wish',
    ],
  ),
  const WalkthroughStep(
    title: 'Pay the Bill',
    description:
        'Once a bill is generated, the button changes to "Pay Bill". Tap it, choose the account to pay from, and confirm. The payment is recorded as an expense + monthly transaction.',
    icon: Icons.payment_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Pay from Bank Account',
    tips: [
      'You can pay from any account â€” bank, wallet, or savings',
      'The bill payment shows up in your expense history',
    ],
  ),
  const WalkthroughStep(
    title: 'Bill vs Outstanding Balance',
    description:
        'If the bill amount is less than the outstanding balance, the remaining amount stays as outstanding on the card.\n\nIf the bill amount is more than the outstanding, the card balance is cleared to zero.',
    icon: Icons.balance_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Bill â‰¤ Outstanding â†’ Remainder stays',
    tips: [
      'Paying less than outstanding means you carry a balance',
      'Paying more than outstanding zeros out the card',
    ],
  ),
];

// Tags
final _tagsSteps = [
  const WalkthroughStep(
    title: 'What are Tags?',
    description:
        'Tags are custom labels you can add to transactions for better organisation. Unlike categories, you can add multiple tags to a single transaction.',
    icon: Icons.label_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Work â€¢ Travel â€¢ Gift',
    tips: [
      'Use tags for projects, trips, or special events',
      'One transaction can have many tags',
    ],
  ),
  const WalkthroughStep(
    title: 'Create Tags',
    description:
        'Go to Profile â†’ Tags â†’ Add Tag. Give it a name, choose a colour and an icon. Tags help you filter and analyse transactions across different categories.',
    icon: Icons.add_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Create Custom Tags',
    tips: [
      'Use meaningful names like "Vacation 2025"',
      'Use distinct colours to identify tags at a glance',
    ],
  ),
  const WalkthroughStep(
    title: 'Add Tags to Transactions',
    description:
        'When adding or editing a transaction, tap the "Tags" field and select one or more tags. This helps you track spending across categories for a specific purpose.',
    icon: Icons.sell_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Select Multiple Tags',
    tips: [
      'You can add tags to existing transactions by editing them',
      'Remove tags anytime',
    ],
  ),
  const WalkthroughStep(
    title: 'View Tagged Transactions',
    description:
        'In the Tags screen, tap any tag to see all transactions with that label. The app shows total spending and income for each tag.',
    icon: Icons.filter_list_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Filter by Tag',
    tips: [
      'Great for tracking project expenses',
      'See exactly how much a vacation cost',
    ],
  ),
];

// Budgets
final _budgetsSteps = [
  const WalkthroughStep(
    title: 'Set Monthly Budgets',
    description:
        'Budgets let you set spending limits for the whole month or individual categories. Go to the Budget tab to get started.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Set Spending Limits',
    tips: [
      'Start with an overall monthly budget',
      'Add category limits for finer control',
    ],
  ),
  const WalkthroughStep(
    title: 'Budget for Future Months',
    description:
        'Tap the right arrow on the month selector to navigate to upcoming months. You can set budgets for any future month in advance â€” perfect for planning ahead.',
    icon: Icons.calendar_month_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'â† Current  â†’  Next Month',
    tips: [
      'Future months show an "Upcoming" badge in the header',
      'Progress bars are hidden for future months since no spending has happened yet',
    ],
  ),
  const WalkthroughStep(
    title: 'Copy Budget from Previous Month',
    description:
        'When you open a month that has no budget set, a banner appears offering to copy all limits from the previous month. Tap "Copy" to apply them instantly.',
    icon: Icons.content_copy_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Copy from Previous Month?',
    tips: [
      'Both overall and category limits are copied',
      'You can then adjust individual categories after copying',
    ],
  ),
  const WalkthroughStep(
    title: 'Category Budgets â€” Including Custom',
    description:
        'Set limits for any expense category â€” both built-in (Food, Transportâ€¦) and your own custom categories. Custom categories appear at the bottom of the list.',
    icon: Icons.category_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Food: â‚¹5,000  â€¢  Pet Care: â‚¹2,000',
    tips: [
      'Tap any category row to set or update its limit',
      'Tap "Clear all" to remove all category limits for that month',
    ],
  ),
  const WalkthroughStep(
    title: 'Track Budget Progress',
    description:
        'Progress bars turn yellow when you reach 80% of a limit, and red when you exceed it. The overall budget card shows spent vs remaining at the top.',
    icon: Icons.show_chart_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'ðŸŸ¢ 65%  ðŸŸ¡ 80%  ðŸ”´ Exceeded',
    tips: [
      'Check your budget tab regularly to stay on track',
      'Adjust the limit if your circumstances change mid-month',
    ],
  ),
];

// Exclude from Expenses
final _excludeExpenseSteps = [
  const WalkthroughStep(
    title: 'What is "Exclude from Expenses"?',
    description:
        'Some transactions should not count toward your expense totals â€” like investments, savings transfers, or loan repayments. This toggle keeps your expense reports accurate.',
    icon: Icons.calculate_outlined,
    color: Color(0xFF9B59B6),
    visualHint: 'Not an Expense',
    tips: [
      'Useful for investment purchases',
      'EMI parent transactions are auto-excluded',
    ],
  ),
  const WalkthroughStep(
    title: 'How to Exclude a Transaction',
    description:
        'When adding or editing a transaction, enable the "Exclude from Expense" toggle. The transaction is still recorded and visible in lists â€” it just does not affect expense totals or budget tracking.',
    icon: Icons.toggle_on_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Enable Toggle',
    tips: [
      'The transaction still appears in your history',
      'It will not be counted in Analytics spending charts',
    ],
  ),
  const WalkthroughStep(
    title: 'When to Use This',
    description:
        'Common use cases:\n\nâ€¢ Investment purchases\nâ€¢ Savings transfers\nâ€¢ Loan repayments\nâ€¢ Money lent to others\nâ€¢ Any amount that is not really day-to-day spending',
    icon: Icons.checklist_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Common Use Cases',
    tips: [
      'Keeps your budget tracking clean',
      'Helps Analytics show true lifestyle spending',
    ],
  ),
];

// Managing Accounts
final _accountsSteps = [
  const WalkthroughStep(
    title: 'Add Your Accounts',
    description:
        'Go to Profile â†’ Accounts to add your bank accounts, wallets, cash, credit cards, and savings accounts.',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Bank â€¢ Wallet â€¢ Cash',
    tips: [
      'Add all accounts you use regularly',
      'You can have multiple accounts of the same type',
    ],
  ),
  const WalkthroughStep(
    title: 'Account Types',
    description:
        'Choose from:\n\nâ€¢ Bank Account\nâ€¢ Digital Wallet\nâ€¢ Cash\nâ€¢ Credit Card\nâ€¢ Savings Account\n\nEach type has its own features and display.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF3498DB),
    visualHint: '5 Account Types',
    tips: [
      'Credit cards track utilisation percentage',
      'Cash accounts do not need bank details',
    ],
  ),
  const WalkthroughStep(
    title: 'View Account Balances',
    description:
        'The home screen shows all your accounts with current balances. Tap any account to see its full transaction history and details.',
    icon: Icons.visibility_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Quick Balance View',
    tips: [
      'Balances update automatically with every transaction',
      'Swipe the account cards to see all accounts',
    ],
  ),
];

// Backup & Restore
final _backupSteps = [
  const WalkthroughStep(
    title: 'Why Back Up?',
    description:
        'Backing up your data ensures you never lose your financial records. SpendFlux stores backups securely in your own Google Drive.',
    icon: Icons.cloud_upload_rounded,
    color: Color(0xFF4285F4),
    visualHint: 'Secure Cloud Backup',
    tips: [
      'Only you can access your Drive backups',
      'Back up before switching phones or reinstalling',
    ],
  ),
  const WalkthroughStep(
    title: 'Create a Backup',
    description:
        'Go to Profile â†’ Backup to Google Drive. A sheet appears where you can optionally name your backup file. Leave the name blank to use the default timestamp name, or type a custom name.',
    icon: Icons.backup_rounded,
    color: Color(0xFF4285F4),
    visualHint: 'Name it or leave blank',
    tips: [
      'The default name includes the date and time automatically',
      'Custom names must be unique â€” the app checks for duplicates before uploading',
    ],
  ),
  const WalkthroughStep(
    title: 'Duplicate Name Check',
    description:
        'If you enter a custom name that already exists on your Drive, the app shows an inline error and prevents the upload. Choose a different name or leave the field blank.',
    icon: Icons.error_outline_rounded,
    color: Color(0xFF4285F4),
    visualHint: '"my_backup.db" already exists',
    tips: [
      'The check happens before the upload starts',
      'Blank names always use a unique timestamp so there is no conflict',
    ],
  ),
  const WalkthroughStep(
    title: 'Auto-Backup',
    description:
        'Enable Auto-Backup in Profile to have SpendFlux back up your data automatically once a day. You can choose an existing Drive file to overwrite, or create a new one.',
    icon: Icons.schedule_rounded,
    color: Color(0xFF7B61FF),
    visualHint: 'Daily at chosen time',
    tips: [
      'Auto-backup only runs when the app is open',
      'You can change the target file anytime from Auto-Backup settings',
    ],
  ),
  const WalkthroughStep(
    title: 'Restore from Backup',
    description:
        'Go to Profile â†’ Restore from Google Drive. A list of all your backups appears with their dates. Tap one to restore â€” your current data will be replaced.',
    icon: Icons.restore_rounded,
    color: Color(0xFF34A853),
    visualHint: 'Select & Restore',
    tips: [
      'Restoring replaces ALL current data â€” make a fresh backup first if needed',
      'Services refresh automatically after restore, no restart required',
    ],
  ),
  const WalkthroughStep(
    title: 'Delete Old Backups',
    description:
        'In the restore sheet, swipe a backup left or tap the trash icon to delete it from Google Drive permanently. A confirmation dialog prevents accidental deletion.',
    icon: Icons.delete_rounded,
    color: Color(0xFFE74C3C),
    visualHint: 'Swipe left to delete',
    tips: [
      'Deleted backups cannot be recovered',
      'Keep at least one recent backup at all times',
    ],
  ),
];

// Custom Categories
final _customCategoriesSteps = [
  const WalkthroughStep(
    title: 'Built-in vs Custom Categories',
    description:
        'SpendFlux comes with built-in categories for common expenses, income and transfers. You can also create your own custom categories with a name, icon and colour.',
    icon: Icons.category_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Built-in + Your Own',
    tips: [
      'Built-in categories cannot be edited or deleted',
      'Custom categories appear alongside built-ins everywhere in the app',
    ],
  ),
  const WalkthroughStep(
    title: 'Create a Custom Category',
    description:
        'Go to Profile â†’ Categories and tap the + button. Give it a name, pick an icon from the library, choose a colour, and select whether it is for expenses or income.',
    icon: Icons.add_circle_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Name â€¢ Icon â€¢ Colour',
    tips: [
      'Use descriptive names like "Pet Care" or "Side Hustle"',
      'Pick a colour that helps you identify it at a glance',
    ],
  ),
  const WalkthroughStep(
    title: 'Custom Categories in Budgets',
    description:
        'Custom expense categories automatically appear in the Budget screen alongside built-in ones. You can set spending limits for them just like any other category.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Budget: Pet Care â‚¹1,000',
    tips: [
      'Custom categories appear at the bottom of the budget list',
      'Their budgets are tracked separately from built-in categories',
    ],
  ),
  const WalkthroughStep(
    title: 'Edit or Delete Custom Categories',
    description:
        'Tap any custom category card to edit its name, icon or colour, or delete it. Built-in categories cannot be modified.',
    icon: Icons.edit_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Tap to Edit or Delete',
    tips: [
      'Deleting a category does not delete its transactions',
      'Existing transactions keep their category assignment',
    ],
  ),
];

// Analytics
final _analyticsSteps = [
  const WalkthroughStep(
    title: 'Open Analytics',
    description:
        'Tap the bar chart icon in the top-right corner of the home screen to open Analytics. View a detailed breakdown of your spending for any month.',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Tap the chart icon',
    tips: [
      'Analytics covers expense transactions',
      'Income is shown in the Monthly Trend chart for comparison',
    ],
  ),
  const WalkthroughStep(
    title: 'Navigate Between Months',
    description:
        'Use the left and right arrows to move between months, or tap the month label to jump directly to any past month.',
    icon: Icons.calendar_month_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'â† June 2025 â†’',
    tips: [
      'Tap the month label for a quick-jump picker',
      'Data is shown only for months with transactions',
    ],
  ),
  const WalkthroughStep(
    title: 'Spending Breakdown (Pie Chart)',
    description:
        'The donut chart shows your top spending categories. Tap any slice or legend item to highlight it and see the exact amount and percentage in the centre.',
    icon: Icons.pie_chart_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Tap a slice for details',
    tips: [
      'More than 6 categories are grouped as "Other"',
      'Tap the same slice again to deselect',
    ],
  ),
  const WalkthroughStep(
    title: 'Monthly Trend (Bar Chart)',
    description:
        'The bar chart shows income and expenses side by side for the last 6 months. Green bars are income, red bars are expenses.',
    icon: Icons.show_chart_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Income vs Expenses',
    tips: [
      'Use this to spot months where you overspent',
      'The current month label is highlighted',
    ],
  ),
  const WalkthroughStep(
    title: 'Spending by Category List',
    description:
        'Below the charts, every category is listed with its total, percentage and a progress bar â€” sorted from highest to lowest spend. Custom categories appear here too.',
    icon: Icons.list_alt_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Sorted by Amount',
    tips: [
      'Tapping a pie slice also highlights the matching row here',
      'Custom categories show their own icon and colour',
    ],
  ),
];
