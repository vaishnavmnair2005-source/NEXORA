import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../utils/constants.dart';
import '../../widgets/gradient_button.dart';
import '../patient_registration_flow.dart'; 

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Setup Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 2. Define Fade Effect (0.0 -> 1.0)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    // 3. Define Slide Up Effect
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback
      body: Stack(
        children: [
          // --- LAYER 1: PROFESSIONAL GRADIENT BACKGROUND ---
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  Color(0xFF1A237E), // Deep Medical Blue (Center spotlight)
                  Color(0xFF000000), // Pure Black (Edges)
                ],
                stops: [0.0, 0.8],
              ),
            ),
          ),

          // --- LAYER 2: TECH GRID PATTERN (Subtle Background) ---
          // This adds that "Digital Twin" engineering look
          Positioned.fill(
            child: Opacity(
              opacity: 0.05, // Very faint
              child: CustomPaint(painter: GridPatternPainter()),
            ),
          ),

          // --- LAYER 3: ANIMATED CONTENT ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      
                      // --- GLOWING LOGO CONTAINER ---
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 50,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          height: 120,
                          errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.health_and_safety, size: 80, color: AppColors.primary),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // --- TYPOGRAPHY ---
                      Text(
                        "MEDITWIN", 
                        style: AppTextStyles.brandMain.copyWith(
                          fontSize: 36, 
                          letterSpacing: 2.0,
                          shadows: [
                            const Shadow(color: Colors.blueAccent, blurRadius: 20)
                          ]
                        )
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 30, height: 1, color: Colors.white24),
                          const SizedBox(width: 10),
                          const Text(
                            "BY NEXORA",
                            style: TextStyle(
                              color: AppColors.primary, 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 30, height: 1, color: Colors.white24),
                        ],
                      ),
                      
                      const Spacer(flex: 1),

                      // --- TAGLINE WITH GLASS EFFECT ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Text(
                          "Where Intelligence Meets Humanity",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // --- PULSING BUTTON ---
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 1.0, end: 1.05),
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: GradientButton(
                              text: "Initialize System", // More "Tech" wording than "Sign Up"
                              onPressed: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => const PatientRegistrationFlow())
                                );
                              },
                            ),
                          );
                        },
                        onEnd: () {}, // Loop logic can be added here if needed
                      ),
                      
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 🎨 CUSTOM PAINTER FOR BACKGROUND GRID ---
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 40; // Grid spacing

    for (double x = 0; x < size.width; x += step) {
      // Draw vertical lines with random gaps to look like "data rain"
      if (x % 80 == 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }

    for (double y = 0; y < size.height; y += step) {
      // Draw horizontal lines
      if (y % 120 == 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
    
    // Draw some random "Data Points" (Medical Crosses)
    final random = math.Random(42); // Fixed seed for consistent pattern
    for (int i = 0; i < 10; i++) {
      double dx = random.nextDouble() * size.width;
      double dy = random.nextDouble() * size.height;
      
      canvas.drawLine(Offset(dx - 5, dy), Offset(dx + 5, dy), paint); // Horizontal part of +
      canvas.drawLine(Offset(dx, dy - 5), Offset(dx, dy + 5), paint); // Vertical part of +
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}