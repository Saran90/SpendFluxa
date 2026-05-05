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
      case FeatureType.recurring:
        return _recurringSteps;
      case FeatureType.reminders:
        return _remindersSteps;
      case FeatureType.creditCard:
        return _creditCardSteps;
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
      case FeatureType.recurring:
        return 'Recurring Transactions';
      case FeatureType.reminders:
        return 'Reminders';
      case FeatureType.creditCard:
        return 'Credit Cards & EMI';
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
                            '• ',
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

// Walkthrough content for each feature
final _addTransactionSteps = [
  const WalkthroughStep(
    title: 'Tap the + Button',
    description:
        'On the home screen, tap the floating action button (+ icon) at the bottom center to start adding a new transaction.',
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
        'Select whether this is an Expense, Income, or Transfer. The screen color changes based on your selection:\n\n• Red for Expenses\n• Green for Income\n• Blue for Transfers',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Expense • Income • Transfer',
    tips: [
      'Most transactions are expenses',
      'Use Transfer to move money between accounts',
    ],
  ),
  const WalkthroughStep(
    title: 'Enter Amount',
    description:
        'Type the transaction amount in the large input field. The currency symbol is shown automatically based on your settings.',
    icon: Icons.currency_rupee_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: '₹ 1,500',
    tips: [
      'You can use decimal points for precise amounts',
      'The app formats large numbers automatically',
    ],
  ),
  const WalkthroughStep(
    title: 'Add Title & Category',
    description:
        'Give your transaction a name (optional) and select a category. Categories help you understand where your money goes.',
    icon: Icons.category_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Grocery Shopping',
    tips: [
      'If you don\'t add a title, the category name is used',
      'You can create custom categories in Settings',
    ],
  ),
  const WalkthroughStep(
    title: 'Select Date & Account',
    description:
        'Choose the transaction date and the account it belongs to. You can also add notes and tags for better organization.',
    icon: Icons.calendar_today_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Today • Primary Bank',
    tips: [
      'Tap the date to pick a different day',
      'Select the account where money was spent/received',
    ],
  ),
  const WalkthroughStep(
    title: 'Save Transaction',
    description:
        'Tap the "Save" button to record your transaction. It will appear in your transaction list and update your balance.',
    icon: Icons.check_circle_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Transaction Saved!',
    tips: [
      'You can edit transactions later by tapping on them',
      'Deleted transactions can\'t be recovered',
    ],
  ),
];

final _recurringSteps = [
  const WalkthroughStep(
    title: 'What are Recurring Transactions?',
    description:
        'Recurring transactions are regular payments that happen automatically, like subscriptions, rent, or salary. Instead of adding them manually each month, you set them up once.',
    icon: Icons.repeat_rounded,
    color: AppColors.primary,
    visualHint: 'Netflix • Rent • Salary',
    tips: [
      'Perfect for monthly bills and subscriptions',
      'Saves time on repetitive entries',
    ],
  ),
  const WalkthroughStep(
    title: 'Create a Recurring Transaction',
    description:
        'When adding a transaction, enable the "Recurring" toggle. Choose the frequency (daily, weekly, monthly, or yearly) and optionally set an end date.',
    icon: Icons.toggle_on_rounded,
    color: AppColors.primary,
    visualHint: 'Enable Recurring Toggle',
    tips: [
      'Monthly is the most common frequency',
      'Set an end date if the subscription has a fixed term',
    ],
  ),
  const WalkthroughStep(
    title: 'Confirmation Banner',
    description:
        'On the due date, a banner appears on your home screen asking you to confirm the transaction. This gives you control over each occurrence.',
    icon: Icons.notification_important_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'DUE TODAY',
    tips: [
      'You can skip a month by tapping "Not Now"',
      'Tap "Record" to create the transaction',
    ],
  ),
  const WalkthroughStep(
    title: 'User Confirmation Required',
    description:
        'Unlike other apps that auto-create transactions, SpendFluxa requires your approval. This prevents unwanted entries if you cancel a subscription or skip a payment.',
    icon: Icons.verified_user_rounded,
    color: AppColors.primary,
    visualHint: 'You\'re in Control',
    tips: [
      'Each occurrence needs separate confirmation',
      'Skipped transactions won\'t appear in your history',
    ],
  ),
  const WalkthroughStep(
    title: 'Managing Recurring Transactions',
    description:
        'View all your recurring transactions in the "Recurring Transactions" section on the home screen. Tap any card to edit or delete it.',
    icon: Icons.edit_rounded,
    color: AppColors.primary,
    visualHint: 'Tap to Edit',
    tips: [
      'Changes apply to future occurrences only',
      'Past confirmed transactions remain unchanged',
    ],
  ),
];

final _remindersSteps = [
  const WalkthroughStep(
    title: 'Set Up Reminders',
    description:
        'Reminders help you remember upcoming recurring transactions. Tap on a recurring transaction, then tap "Manage Reminders" to set them up.',
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
        'Select when you want to be reminded:\n\n• Same day\n• 1 day before\n• 2 days before\n• 3 days before\n• 1 week before\n\nAlso choose the time of day for the reminder.',
    icon: Icons.access_time_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: '2 days before at 9:00 AM',
    tips: [
      'Set reminders a few days early to prepare',
      'Choose a time when you usually check your phone',
    ],
  ),
  const WalkthroughStep(
    title: 'Reminder Banner',
    description:
        'When a reminder is due, a banner appears on your home screen showing the upcoming transaction details and when it\'s due.',
    icon: Icons.campaign_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'IN 2 DAYS',
    tips: [
      'Reminders appear up to 7 days in advance',
      'The banner shows the transaction amount and date',
    ],
  ),
  const WalkthroughStep(
    title: 'Enable/Disable Reminders',
    description:
        'You can toggle reminders on or off anytime. Disabled reminders won\'t show notifications but remain saved for future use.',
    icon: Icons.toggle_off_rounded,
    color: Color(0xFF4ECDC4),
    visualHint: 'Toggle On/Off',
    tips: ['Useful when you\'re on vacation', 'Re-enable them when you return'],
  ),
];

final _creditCardSteps = [
  const WalkthroughStep(
    title: 'Add a Credit Card Account',
    description:
        'Go to Profile → Accounts → Add Account. Select "Credit Card" as the account type and enter your card details including credit limit and bill date.',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Credit Card Account',
    tips: ['Enter your total credit limit', 'Set the bill date for tracking'],
  ),
  const WalkthroughStep(
    title: 'Track Credit Card Spending',
    description:
        'When adding an expense, select your credit card as the account. The app automatically tracks your outstanding balance and shows utilization percentage.',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: '45% Utilized',
    tips: [
      'Keep utilization below 30% for good credit health',
      'The app shows a progress bar on the home screen',
    ],
  ),
  const WalkthroughStep(
    title: 'EMI Transactions',
    description:
        'For purchases with EMI, enable the "EMI" toggle when adding a transaction. Enter the interest rate and duration in months.',
    icon: Icons.payments_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: '12 months @ 12% p.a.',
    tips: [
      'The app calculates monthly EMI automatically',
      'EMI transactions are excluded from expense totals',
    ],
  ),
  const WalkthroughStep(
    title: 'How EMI Works',
    description:
        'The app creates a parent transaction for the full amount and individual monthly installments. This helps you track both the total debt and monthly payments.',
    icon: Icons.account_tree_rounded,
    color: Color(0xFF5C6BC0),
    visualHint: 'Parent + Installments',
    tips: [
      'Parent transaction shows total amount',
      'Monthly installments appear on their due dates',
    ],
  ),
];

final _tagsSteps = [
  const WalkthroughStep(
    title: 'What are Tags?',
    description:
        'Tags are custom labels you can add to transactions for better organization. Unlike categories, you can add multiple tags to a single transaction.',
    icon: Icons.label_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Work • Travel • Gift',
    tips: [
      'Use tags for projects, trips, or special events',
      'One transaction can have many tags',
    ],
  ),
  const WalkthroughStep(
    title: 'Create Tags',
    description:
        'Go to Profile → Tags → Add Tag. Give it a name, choose a color and icon. Tags help you filter and analyze transactions across categories.',
    icon: Icons.add_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Create Custom Tags',
    tips: [
      'Choose meaningful names like "Vacation 2024"',
      'Use colors to quickly identify tags',
    ],
  ),
  const WalkthroughStep(
    title: 'Add Tags to Transactions',
    description:
        'When adding or editing a transaction, tap the "Tags" field and select one or more tags. This helps you track spending for specific purposes.',
    icon: Icons.sell_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Select Multiple Tags',
    tips: [
      'You can add tags to existing transactions',
      'Remove tags anytime by editing the transaction',
    ],
  ),
  const WalkthroughStep(
    title: 'View Tagged Transactions',
    description:
        'In the Tags screen, tap any tag to see all transactions with that tag. The app shows total spending and income for each tag.',
    icon: Icons.filter_list_rounded,
    color: Color(0xFFFF9800),
    visualHint: 'Filter by Tag',
    tips: [
      'Great for tracking project expenses',
      'See how much you spent on a vacation',
    ],
  ),
];

final _budgetsSteps = [
  const WalkthroughStep(
    title: 'Set Monthly Budgets',
    description:
        'Budgets help you control spending by setting limits for each category or overall expenses. Go to the Budget tab to create your first budget.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Set Spending Limits',
    tips: [
      'Start with an overall budget',
      'Add category budgets for better control',
    ],
  ),
  const WalkthroughStep(
    title: 'Track Budget Progress',
    description:
        'The home screen shows budget cards with progress bars. Green means you\'re within budget, red means you\'ve exceeded it.',
    icon: Icons.show_chart_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: '65% of Budget Used',
    tips: [
      'Check your budget daily',
      'Adjust spending if you\'re close to the limit',
    ],
  ),
  const WalkthroughStep(
    title: 'Category Budgets',
    description:
        'Set individual budgets for categories like Food, Transport, or Entertainment. This helps you identify where you overspend.',
    icon: Icons.category_rounded,
    color: Color(0xFF2D9E6B),
    visualHint: 'Food: ₹5,000/month',
    tips: [
      'Focus on categories where you spend most',
      'Be realistic with your limits',
    ],
  ),
];

final _excludeExpenseSteps = [
  const WalkthroughStep(
    title: 'What is "Exclude from Expenses"?',
    description:
        'Some transactions shouldn\'t count toward your expense totals, like investments, savings transfers, or EMI payments. Use this feature to exclude them.',
    icon: Icons.calculate_outlined,
    color: Color(0xFF9B59B6),
    visualHint: 'Not an Expense',
    tips: [
      'Useful for investment transactions',
      'EMI transactions are auto-excluded',
    ],
  ),
  const WalkthroughStep(
    title: 'How to Exclude Transactions',
    description:
        'When adding or editing a transaction, enable the "Exclude from Expense" toggle. The transaction will still be recorded but won\'t affect your expense totals.',
    icon: Icons.toggle_on_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Enable Toggle',
    tips: [
      'The transaction still appears in your list',
      'It just doesn\'t count in expense calculations',
    ],
  ),
  const WalkthroughStep(
    title: 'When to Use This',
    description:
        'Use this for:\n\n• Investment purchases\n• Savings transfers\n• Loan repayments\n• Money given as loans\n• Any transaction that\'s not really an expense',
    icon: Icons.checklist_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Common Use Cases',
    tips: ['Keeps your expense reports accurate', 'Helps with budgeting'],
  ),
];

final _accountsSteps = [
  const WalkthroughStep(
    title: 'Add Your Accounts',
    description:
        'Go to Profile → Accounts to add your bank accounts, wallets, cash, credit cards, and savings accounts. This helps track where your money is.',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Bank • Wallet • Cash',
    tips: [
      'Add all accounts you use regularly',
      'You can add multiple accounts of the same type',
    ],
  ),
  const WalkthroughStep(
    title: 'Account Types',
    description:
        'Choose from:\n\n• Bank Account\n• Digital Wallet\n• Cash\n• Credit Card\n• Savings Account\n\nEach type has specific features and tracking.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF3498DB),
    visualHint: '5 Account Types',
    tips: [
      'Credit cards show utilization percentage',
      'Cash accounts don\'t need bank details',
    ],
  ),
  const WalkthroughStep(
    title: 'View Account Balances',
    description:
        'The home screen shows all your accounts with current balances. Tap any account to see its transaction history and details.',
    icon: Icons.visibility_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Quick Balance View',
    tips: [
      'Balances update automatically with transactions',
      'Swipe horizontally to see all accounts',
    ],
  ),
];

final _backupSteps = [
  const WalkthroughStep(
    title: 'Why Backup?',
    description:
        'Backing up your data ensures you never lose your financial records. SpendFluxa uses Google Drive to securely store your data.',
    icon: Icons.cloud_upload_rounded,
    color: Color(0xFF4285F4),
    visualHint: 'Secure Cloud Backup',
    tips: ['Backups are encrypted', 'Only you can access your data'],
  ),
  const WalkthroughStep(
    title: 'Create a Backup',
    description:
        'Go to Profile → Backup to Google Drive. Sign in with your Google account and tap the backup button. Your data is uploaded securely.',
    icon: Icons.backup_rounded,
    color: Color(0xFF4285F4),
    visualHint: 'One-Tap Backup',
    tips: [
      'Backup regularly, especially before major changes',
      'The app shows when you last backed up',
    ],
  ),
  const WalkthroughStep(
    title: 'Restore from Backup',
    description:
        'If you switch devices or reinstall the app, go to Profile → Restore from Google Drive. Select a backup and your data will be restored.',
    icon: Icons.restore_rounded,
    color: Color(0xFF34A853),
    visualHint: 'Restore Anytime',
    tips: [
      'You can see all available backups with dates',
      'Restoring replaces current data',
    ],
  ),
];

final _customCategoriesSteps = [
  const WalkthroughStep(
    title: 'Built-in vs Custom Categories',
    description:
        'SpendSense comes with a set of built-in categories for common expenses and income types. You can also create your own custom categories with a name, icon, and color of your choice.',
    icon: Icons.category_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Built-in + Your Own',
    tips: [
      'Built-in categories cannot be edited or deleted',
      'Custom categories appear alongside built-ins when adding transactions',
    ],
  ),
  const WalkthroughStep(
    title: 'Create a Custom Category',
    description:
        'Go to Profile → Categories and tap the + button. Give your category a name, pick an icon from the icon library, and choose a color. Select whether it\'s for expenses or income.',
    icon: Icons.add_circle_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Name • Icon • Color',
    tips: [
      'Use descriptive names like "Pet Care" or "Side Hustle"',
      'Pick a color that helps you identify it at a glance',
    ],
  ),
  const WalkthroughStep(
    title: 'Edit or Delete Custom Categories',
    description:
        'Tap any custom category card to see options. You can edit its name, icon, or color, or delete it entirely. Built-in categories cannot be modified.',
    icon: Icons.edit_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Tap to Edit or Delete',
    tips: [
      'Deleting a category does not delete its transactions',
      'Existing transactions keep their category assignment',
    ],
  ),
  const WalkthroughStep(
    title: 'Using Custom Categories',
    description:
        'When adding or editing a transaction, tap the Category field. Your custom categories appear in the same picker as built-in ones. They also show up correctly in Analytics and budget tracking.',
    icon: Icons.sell_rounded,
    color: Color(0xFF9B59B6),
    visualHint: 'Available Everywhere',
    tips: [
      'Custom categories are shown with a colored dot badge',
      'They appear in the Analytics spending breakdown with their own color',
    ],
  ),
];

final _analyticsSteps = [
  const WalkthroughStep(
    title: 'Open Analytics',
    description:
        'Tap the bar chart icon in the top-right corner of the home screen to open Analytics. You can view a detailed breakdown of your spending for any month.',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Tap the chart icon',
    tips: [
      'Analytics only covers expense transactions',
      'Income is shown in the Monthly Trend chart for comparison',
    ],
  ),
  const WalkthroughStep(
    title: 'Navigate Between Months',
    description:
        'Use the left and right arrows at the top to move between months. Tap the month label directly to pick any month from the last 2 years using the month picker.',
    icon: Icons.calendar_month_rounded,
    color: Color(0xFF3498DB),
    visualHint: '← June 2025 →',
    tips: [
      'You cannot navigate beyond the current month',
      'Tap the month label for a quick jump to any past month',
    ],
  ),
  const WalkthroughStep(
    title: 'Spending Breakdown (Pie Chart)',
    description:
        'The donut chart shows your top spending categories for the selected month. Tap any slice or legend item to highlight it and see the exact amount and percentage in the centre.',
    icon: Icons.pie_chart_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Tap a slice for details',
    tips: [
      'If you have more than 6 categories, the smallest ones are grouped as "Other"',
      'Tap the same slice again to deselect it',
    ],
  ),
  const WalkthroughStep(
    title: 'Monthly Trend (Bar Chart)',
    description:
        'The bar chart shows your income and expenses side by side for the last 6 months ending at the selected month. Green bars are income, red bars are expenses.',
    icon: Icons.show_chart_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Income vs Expenses',
    tips: [
      'The current month\'s label is highlighted in the app\'s primary color',
      'Use this to spot months where you overspent',
    ],
  ),
  const WalkthroughStep(
    title: 'Spending by Category List',
    description:
        'Below the charts, every category is listed with its total amount, percentage of total spending, and a progress bar. Categories are sorted from highest to lowest spend.',
    icon: Icons.list_alt_rounded,
    color: Color(0xFF3498DB),
    visualHint: 'Sorted by Amount',
    tips: [
      'Custom categories appear here with their own icon and color',
      'Tapping a pie slice dims all other categories in this list too',
    ],
  ),
];
