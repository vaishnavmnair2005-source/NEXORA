import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../utils/constants.dart';
import 'auth/welcome_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN — 4 animated slides for first-time users
// Navigate here from SplashScreen when onboarding hasn't been completed.
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _bgController;
  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  static const List<_OnboardingData> _slides = [
    _OnboardingData(
      icon: Icons.health_and_safety_rounded,
      iconColor: Color(0xFF00E5FF),
      title: 'Your Digital Health Twin',
      subtitle:
          'MediTwin creates a real-time digital replica of your health state — monitoring vitals, detecting anomalies, and keeping your care team informed 24/7.',
      accent: Color(0xFF00E5FF),
    ),
    _OnboardingData(
      icon: Icons.sensors_rounded,
      iconColor: Color(0xFF69FF47),
      title: 'ESP-32 Bio-Patch',
      subtitle:
          'Pair your wearable Bio-Patch to stream live ECG, SpO₂, temperature, heart rate variability, and fall detection directly to this app.',
      accent: Color(0xFF69FF47),
    ),
    _OnboardingData(
      icon: Icons.notifications_active_rounded,
      iconColor: Color(0xFFFF6B6B),
      title: 'Intelligent SOS Alerts',
      subtitle:
          'When critical vitals are detected, MediTwin instantly calls your primary caregiver and logs the emergency — so help is always one tap away.',
      accent: Color(0xFFFF6B6B),
    ),
    _OnboardingData(
      icon: Icons.show_chart_rounded,
      iconColor: Color(0xFFFFD740),
      title: 'Trends & Insights',
      subtitle:
          'Visualise your health trends over time. Export detailed PDF reports to share with your doctor at your next appointment.',
      accent: Color(0xFFFFD740),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();

    _contentController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _contentController, curve: Curves.easeOut));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _contentController, curve: Curves.easeOutCubic));

    _contentController.forward();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _contentController.forward(from: 0);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _slides[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              painter: _OnboardingBgPainter(
                  _bgController.value, current.accent),
              size: Size.infinite,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Skip button ──────────────────────────────────────
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 20),
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 15,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),

                // ── Slide content ────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _slides.length,
                    itemBuilder: (_, i) =>
                        _SlideContent(data: _slides[i]),
                  ),
                ),

                // ── Dot indicators ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _currentPage
                            ? current.accent
                            : Colors.white24,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Action button ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: GestureDetector(
                    onTap: _nextPage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            current.accent.withOpacity(0.9),
                            current.accent.withOpacity(0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: current.accent.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage < _slides.length - 1
                                  ? 'Next'
                                  : 'Get Started',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              _currentPage < _slides.length - 1
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE SLIDE WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _SlideContent extends StatefulWidget {
  final _OnboardingData data;
  const _SlideContent({required this.data});

  @override
  State<_SlideContent> createState() => _SlideContentState();
}

class _SlideContentState extends State<_SlideContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon hero
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.data.accent.withOpacity(0.08),
                  border: Border.all(
                      color: widget.data.accent.withOpacity(0.25), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: widget.data.accent.withOpacity(0.2),
                        blurRadius: 50,
                        spreadRadius: 10),
                  ],
                ),
                child: Icon(widget.data.icon,
                    size: 64, color: widget.data.iconColor),
              ),

              const SizedBox(height: 48),

              // Accent line
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: widget.data.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                widget.data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 20),

              // Body
              Text(
                widget.data.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color accent;

  const _OnboardingData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingBgPainter extends CustomPainter {
  final double t;
  final Color accent;
  _OnboardingBgPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment.topCenter,
        radius: 1.3,
        colors: [Color(0xFF060D1E), Color(0xFF000000)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Floating orb
    final orbY =
        size.height * 0.3 + 40 * math.sin(t * 2 * math.pi);
    final orb = Paint()
      ..shader = RadialGradient(
        colors: [accent.withOpacity(0.07), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.5, orbY), radius: 200));
    canvas.drawCircle(Offset(size.width * 0.5, orbY), 200, orb);

    // Grid lines
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_OnboardingBgPainter old) =>
      old.t != t || old.accent != accent;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Checks if onboarding is done; if not, shows OnboardingScreen first.
// Use this in SplashScreen._checkSessionAndNavigate() as a pre-check.
//
// Example usage in splash_screen.dart:
//
//   final seenOnboarding = await OnboardingGuard.hasCompleted();
//   if (!seenOnboarding) {
//     Navigator.pushReplacement(ctx,
//       MaterialPageRoute(builder: (_) => const OnboardingScreen()));
//     return;
//   }
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingGuard {
  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_complete');
  }
}