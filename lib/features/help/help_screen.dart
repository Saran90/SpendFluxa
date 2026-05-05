import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'walkthrough_data.dart';
import 'feature_walkthrough_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
          'Help & Support',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Getting Started'),
          _buildFeatureCard(
            context,
            icon: Icons.add_circle_rounded,
            title: 'Adding Transactions',
            description: 'Learn how to record your income and expenses',
            color: const Color(0xFF4ECDC4),
            featureType: FeatureType.addTransaction,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: 'Managing Accounts',
            description:
                'Set up and manage your bank accounts and credit cards',
            color: const Color(0xFF3498DB),
            featureType: FeatureType.accounts,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Advanced Features'),
          _buildFeatureCard(
            context,
            icon: Icons.repeat_rounded,
            title: 'Recurring Transactions',
            description: 'Automate regular payments with user confirmation',
            color: AppColors.primary,
            featureType: FeatureType.recurring,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.notifications_rounded,
            title: 'Reminders',
            description: 'Set up reminders for upcoming transactions',
            color: const Color(0xFF4ECDC4),
            featureType: FeatureType.reminders,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.credit_card_rounded,
            title: 'Credit Cards & EMI',
            description: 'Track credit card spending and EMI payments',
            color: const Color(0xFF5C6BC0),
            featureType: FeatureType.creditCard,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.label_rounded,
            title: 'Tags',
            description: 'Organize transactions with custom tags',
            color: const Color(0xFFFF9800),
            featureType: FeatureType.tags,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            title: 'Budgets',
            description: 'Set spending limits and track your progress',
            color: const Color(0xFF2D9E6B),
            featureType: FeatureType.budgets,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.calculate_outlined,
            title: 'Exclude from Expenses',
            description: 'Mark transactions to exclude from expense totals',
            color: const Color(0xFF9B59B6),
            featureType: FeatureType.excludeExpense,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.category_rounded,
            title: 'Custom Categories',
            description: 'Create your own categories with custom icons and colors',
            color: const Color(0xFF9B59B6),
            featureType: FeatureType.customCategories,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.bar_chart_rounded,
            title: 'Analytics',
            description: 'Visualise spending with pie charts and monthly trends',
            color: const Color(0xFF3498DB),
            featureType: FeatureType.analytics,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Data & Backup'),
          _buildFeatureCard(
            context,
            icon: Icons.backup_rounded,
            title: 'Backup & Restore',
            description: 'Keep your data safe with Google Drive backup',
            color: const Color(0xFF4285F4),
            featureType: FeatureType.backup,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required FeatureType featureType,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeatureWalkthroughScreen(featureType: featureType),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
