import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'auth/welcome_screen.dart';
import 'main_screen.dart';          
import 'onboarding_screen.dart';    
import 'biometric_lock.dart';       

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _zoomController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  final String _tagline = "Where Intelligence Meets Humanity";
  String _displayedTagline = "";
  int _charIndex = 0;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();

    // 1. Cinematic Zoom Animation
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _logoScale = Tween<double>(begin: 0.05, end: 2.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _zoomController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _zoomController.forward();

    // 2. Start Typewriter
    Future.delayed(const Duration(milliseconds: 800), () => _startTypewriter());

    // 3. Check Session after 4 seconds
    Timer(const Duration(seconds: 4), _checkSessionAndNavigate);
  }

  void _startTypewriter() {
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_charIndex < _tagline.length) {
        if (mounted) {
          setState(() {
            _displayedTagline += _tagline[_charIndex];
            _charIndex++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  // --- 🔥 NAVIGATION LOGIC (STRICT) ---
  Future<void> _checkSessionAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    
    // ⚠️ IMPORTANT: Ensure 'await prefs.clear()' is NOT here.
    // That line deletes your login data. I have removed it below.

    final int? savedUserId = prefs.getInt('logged_in_user_id'); // ✅ matches registration save key
    final bool onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (!mounted) return;

    Widget destination;

    if (savedUserId != null) {
      // ✅ SCENARIO 1: User is Logged In
      // Skip Onboarding, Skip Welcome. Go Straight to Dashboard.
      destination = BiometricGatedPage(child: MainScreen(userId: savedUserId));
    } 
    else if (onboardingComplete) {
      // ✅ SCENARIO 2: User saw slides, but hasn't logged in yet
      // Skip Onboarding. Go to Signup/Login.
      destination = const WelcomeScreen();
    } 
    else {
      // ✅ SCENARIO 3: Fresh Install OR Account Deleted
      // Show Onboarding Slides.
      destination = const OnboardingScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) => 
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _zoomController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 100,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.health_and_safety, size: 200, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 170),
                SizedBox(
                  height: 30,
                  child: Text(
                    _displayedTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Courier',
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.0),
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary.withOpacity(0.05),
                  ),
                  child: const Text(
                    "BY NEXORA",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}