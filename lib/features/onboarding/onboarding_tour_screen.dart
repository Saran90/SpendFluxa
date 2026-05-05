import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class OnboardingTourScreen extends StatefulWidget {
  const OnboardingTourScreen({super.key});

  @override
  State<OnboardingTourScreen> createState() => _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends State<OnboardingTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to SpendFlux!',
      description:
          'Your personal finance companion that helps you track expenses, manage budgets, and achieve your financial goals.',
      icon: Icons.waving_hand_rounded,
      color: AppColors.primary,
      gradient: AppColors.splashGradient,
    ),
    OnboardingPage(
      title: 'Track Every Transaction',
      description:
          'Easily record your income and expenses with just a few taps. Categorize transactions and add notes for better organization.',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF4ECDC4),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4ECDC4), Color(0xFF2D9E8F)],
      ),
    ),
    OnboardingPage(
      title: 'Smart Recurring Transactions',
      description:
          'Set up recurring transactions for subscriptions and bills. Get reminders and confirm each occurrence with a single tap.',
      icon: Icons.repeat_rounded,
      color: AppColors.primary,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      ),
    ),
    OnboardingPage(
      title: 'Manage Multiple Accounts',
      description:
          'Track all your bank accounts, credit cards, wallets, and cash in one place. See your complete financial picture.',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF3498DB),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
      ),
    ),
    OnboardingPage(
      title: 'Set Budgets & Goals',
      description:
          'Create monthly budgets for different categories. Track your progress and stay within your spending limits.',
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF2D9E6B),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2D9E6B), Color(0xFF1A7A50)],
      ),
    ),
    OnboardingPage(
      title: 'Secure Cloud Backup',
      description:
          'Your data is automatically backed up to Google Drive. Switch devices or reinstall without losing any data.',
      icon: Icons.cloud_done_rounded,
      color: const Color(0xFF4285F4),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4285F4), Color(0xFF3367D6)],
      ),
    ),
    OnboardingPage(
      title: 'Ready to Start!',
      description:
          'You\'re all set! Tap the + button on the home screen to add your first transaction and begin your financial journey.',
      icon: Icons.rocket_launch_rounded,
      color: AppColors.primary,
      gradient: AppColors.splashGradient,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page view
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),

          // Skip button (top right)
          if (_currentPage < _pages.length - 1)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom navigation
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _pages[_currentPage].color,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? 'Next'
                              : 'Get Started',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(gradient: page.gradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 48),

              // Title
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              // Description
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
