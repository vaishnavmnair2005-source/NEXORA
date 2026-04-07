import 'package:flutter/material.dart';
import 'dart:ui'; // Required for Glassmorphism
import '../utils/constants.dart';

class PatientProfileDashboard extends StatelessWidget {
  final Map<String, dynamic> userProfile;

  const PatientProfileDashboard({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    // Exact logic for name and device
    final String fullName = "${userProfile['first_name'] ?? ''} ${userProfile['last_name'] ?? ''}".trim();
    final String deviceId = userProfile['device_id'] ?? '';
    final bool isPaired = deviceId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      // 1. Removed extendBodyBehindAppBar and the standard AppBar entirely
      body: Stack(
        children: [
          // 2. BACKGROUND GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF1A237E), Color(0xFF000000)],
                stops: [0.0, 0.8],
              ),
            ),
          ),

          // 3. TECH GRID PATTERN
          Positioned.fill(
             child: Opacity(
               opacity: 0.05,
               child: CustomPaint(painter: GridPatternPainter()),
             ),
          ),

          // 4. SCROLLABLE CONTENT (Wrapped in SafeArea to avoid notches)
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER (Now scrolls with the page) ---
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(width: 8),
                      const Text("My Profile", style: AppTextStyles.heading1),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // --- BIG HERO AVATAR ---
                  Center(
                    child: Hero(
                      tag: 'profile-avatar',
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20)
                          ],
                        ),
                        child: const Icon(Icons.person, size: 60, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- SYSTEM IDs ---
                  const Text("System Identifiers", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  
                  // Using Glass Card
                  _buildGlassCard(
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.badge, "Patient ID", userProfile['patient_id'] ?? 'N/A'),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(Icons.folder_shared, "MRD Number", userProfile['mrd_number'] ?? 'Not provided'),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(
                          isPaired ? Icons.memory : Icons.memory_outlined, 
                          "Device ID", 
                          isPaired ? deviceId : "No device paired yet"
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // --- PERSONAL INFO ---
                  const Text("Personal Information", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  
                  // Using Glass Card
                  _buildGlassCard(
                    child: Column(
                      children: [
                        _buildProfileRow(Icons.person, "Full Name", fullName),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(Icons.email, "Email", userProfile['email'] ?? 'N/A'),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(Icons.calendar_today, "Date of Birth", userProfile['dob'] ?? 'N/A'),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(Icons.wc, "Gender", userProfile['gender'] ?? 'N/A'),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(Icons.phone, "Contact Number", userProfile['contact_number'] ?? 'N/A'),
                        const Divider(color: Colors.white12, height: 30),
                        _buildProfileRow(Icons.home, "Address", userProfile['address'] ?? 'N/A'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Glass Card Wrapper ---
  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  // --- EXISTING ROW WIDGET ---
  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Grid Painter ---
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white..strokeWidth = 1.0..style = PaintingStyle.stroke;
    const double step = 40;
    for (double x = 0; x < size.width; x += step) {
      if (x % 80 == 0) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      if (y % 120 == 0) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}