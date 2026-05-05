import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final AuthService authService;
  final BiometricService biometricService;

  const SplashScreen({
    super.key,
    required this.authService,
    required this.biometricService,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Background gradient fade-in
  late AnimationController _bgController;
  late Animation<double> _bgOpacity;

  // Floating decorative circles
  late AnimationController _circleController;
  late Animation<double> _circleScale;
  late Animation<double> _circleOpacity;

  // Logo icon bounce + scale
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  // App name slide-up
  late AnimationController _titleController;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;

  // Tagline fade-in
  late AnimationController _taglineController;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  // Bottom accent bar
  late AnimationController _barController;
  late Animation<double> _barWidth;
  late Animation<double> _barOpacity;

  // Coin/chart floating particles
  late AnimationController _particleController;
  late Animation<double> _particleOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _initAnimations();
    _startAnimationSequence();
  }

  void _initAnimations() {
    // Background
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bgOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeIn));

    // Decorative circles
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _circleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.elasticOut),
    );
    _circleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _circleController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
        );

    // Title
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
        );
    _titleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _titleController, curve: Curves.easeIn));

    // Tagline
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _taglineController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Bottom bar
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _barWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic),
    );
    _barOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _barController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _particleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeIn),
    );
  }

  Future<void> _startAnimationSequence() async {
    // Step 1: Background fades in
    await _bgController.forward();

    // Step 2: Decorative circles expand
    _circleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 3: Particles appear
    _particleController.forward();

    // Step 4: Logo bounces in
    await Future.delayed(const Duration(milliseconds: 100));
    await _logoController.forward();

    // Step 5: Title slides up
    await Future.delayed(const Duration(milliseconds: 100));
    _titleController.forward();

    // Step 6: Tagline fades in
    await Future.delayed(const Duration(milliseconds: 200));
    _taglineController.forward();

    // Step 7: Bottom bar sweeps in
    await Future.delayed(const Duration(milliseconds: 200));
    _barController.forward();

    // Navigate after a short pause — go to home if already signed in, else login
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final destination = widget.authService.isSignedIn ? '/home' : '/login';

    // If heading to home and biometric lock is enabled, authenticate first.
    if (destination == '/home' && widget.biometricService.isEnabled) {
      final ok = await widget.biometricService.authenticate(
        reason: 'Authenticate to open SpendFlux',
      );
      if (!mounted) return;
      if (!ok) {
        // Auth failed / cancelled — keep showing splash, retry on next resume.
        // Re-trigger the prompt so the user can try again.
        _startBiometricRetry();
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(destination);
    }
  }

  /// Retries biometric prompt after a short delay (user cancelled).
  Future<void> _startBiometricRetry() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final ok = await widget.biometricService.authenticate(
      reason: 'Authenticate to open SpendFlux',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _startBiometricRetry();
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _circleController.dispose();
    _logoController.dispose();
    _titleController.dispose();
    _taglineController.dispose();
    _barController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgController,
          _circleController,
          _logoController,
          _titleController,
          _taglineController,
          _barController,
          _particleController,
        ]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _bgOpacity,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.splashGradient,
              ),
              child: Stack(
                children: [
                  // ── Decorative background circles ──────────────────────
                  _buildDecorativeCircles(size),

                  // ── Floating particles (coins / dots) ──────────────────
                  _buildParticles(size),

                  // ── Main content ───────────────────────────────────────
                  _buildMainContent(size),

                  // ── Bottom tagline bar ─────────────────────────────────
                  _buildBottomBar(size),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Decorative circles ────────────────────────────────────────────────────

  Widget _buildDecorativeCircles(Size size) {
    return Stack(
      children: [
        // Large circle top-right
        Positioned(
          top: -size.width * 0.25,
          right: -size.width * 0.2,
          child: FadeTransition(
            opacity: _circleOpacity,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
        ),
        // Medium circle top-right (inner)
        Positioned(
          top: -size.width * 0.05,
          right: -size.width * 0.05,
          child: FadeTransition(
            opacity: _circleOpacity,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: size.width * 0.45,
                height: size.width * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
        ),
        // Large circle bottom-left
        Positioned(
          bottom: -size.width * 0.3,
          left: -size.width * 0.25,
          child: FadeTransition(
            opacity: _circleOpacity,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
        ),
        // Small accent circle (coral) mid-left
        Positioned(
          top: size.height * 0.28,
          left: size.width * 0.06,
          child: FadeTransition(
            opacity: _circleOpacity,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),
        // Small accent circle (coral) mid-right
        Positioned(
          top: size.height * 0.62,
          right: size.width * 0.08,
          child: FadeTransition(
            opacity: _circleOpacity,
            child: ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Floating particles ────────────────────────────────────────────────────

  Widget _buildParticles(Size size) {
    return FadeTransition(
      opacity: _particleOpacity,
      child: Stack(
        children: [
          _particle(top: size.height * 0.15, left: size.width * 0.12, size: 8),
          _particle(top: size.height * 0.22, right: size.width * 0.15, size: 6),
          _particle(top: size.height * 0.72, left: size.width * 0.18, size: 5),
          _particle(top: size.height * 0.78, right: size.width * 0.12, size: 7),
          _particle(top: size.height * 0.35, right: size.width * 0.06, size: 5),
          _particle(top: size.height * 0.55, left: size.width * 0.07, size: 6),
          // Coral accent dots
          _particle(
            top: size.height * 0.18,
            right: size.width * 0.3,
            size: 5,
            color: AppColors.accent.withValues(alpha: 0.5),
          ),
          _particle(
            top: size.height * 0.68,
            left: size.width * 0.35,
            size: 4,
            color: AppColors.accent.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _particle({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    Color? color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildMainContent(Size size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo icon
          SlideTransition(
            position: _logoSlide,
            child: FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: _buildLogoIcon(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // App name
          SlideTransition(
            position: _titleSlide,
            child: FadeTransition(
              opacity: _titleOpacity,
              child: _buildAppName(),
            ),
          ),

          const SizedBox(height: 12),

          // Tagline
          SlideTransition(
            position: _taglineSlide,
            child: FadeTransition(
              opacity: _taglineOpacity,
              child: _buildTagline(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoIcon() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: 110,
          height: 110,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'Spend',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 1.5,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: 'Fluxa',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline() {
    return Column(
      children: [
        Text(
          'Smart money, smarter life',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        // Small decorative divider
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 1.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 1.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(Size size) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _barOpacity,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 28,
            top: 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.12)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated sweep bar
              AnimatedBuilder(
                animation: _barWidth,
                builder: (context, _) {
                  return Container(
                    width: size.width * 0.45 * _barWidth.value,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Loading indicator dots
              _buildLoadingDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return _AnimatedDot(delay: Duration(milliseconds: index * 180));
      }),
    );
  }
}

// ── Animated loading dot ──────────────────────────────────────────────────────

class _AnimatedDot extends StatefulWidget {
  final Duration delay;

  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}
