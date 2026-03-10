import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import '../utils/constants.dart';

class CaregiverProfileScreen extends StatefulWidget {
  // We keep userProfile for immediate display of what we have (like phone/relation)
  final Map<String, dynamic> userProfile; 
  final int userId; // 🔥 ADDED: Needed to fetch fresh data

  const CaregiverProfileScreen({
    super.key, 
    required this.userProfile,
    required this.userId, 
  });

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> with TickerProviderStateMixin {
  late AnimationController _floatController;
  bool _isLoading = true;

  // Variables to hold the fresh data
  String _name = "Loading...";
  String _relation = "";
  String _phone = "";

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    
    // 1. Load initial data passed from Dashboard (so it's not empty)
    _name = widget.userProfile['cg_full_name']?.toString() ?? "";
    _relation = widget.userProfile['cg_relation']?.toString() ?? "";
    _phone = widget.userProfile['cg_phone']?.toString() ?? "";

    // 2. 🔥 FETCH FRESH DATA FROM CAREGIVERS TABLE
    _fetchCaregiverDirectly();
  }

  Future<void> _fetchCaregiverDirectly() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/app/get-caregiver/${widget.userId}')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              // Override with fresh data from DB
              _name = data['cg_full_name']?.toString() ?? _name; 
              _relation = data['cg_relation']?.toString() ?? _relation;
              _phone = data['cg_phone']?.toString() ?? _phone;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching caregiver: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If API failed or is still loading, use fallback or what we have
    final displayName = (_name.isEmpty || _name == "Loading...") ? "Updating..." : _name;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Deep Space Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [Color(0xFF1A237E), Color(0xFF000000)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          
          // Glowing Orb Background
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                children: [
                  // Back Button & Title
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text("Caregiver Profile", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // Floating Avatar
                  _buildAnimatedItem(0, AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) => Transform.translate(offset: Offset(0, 10 * _floatController.value), child: child),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 160, height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 60, spreadRadius: 10)],
                            ),
                          ),
                          Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D47A1), Color(0xFF00B4CC)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                            ),
                            child: const Icon(Icons.health_and_safety, size: 65, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )),

                  const SizedBox(height: 30),

                  // Name Section (Highlight)
                  _buildAnimatedItem(1, Column(
                    children: [
                      const Text("PRIMARY CAREGIVER", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                      const SizedBox(height: 8),
                      // 🔥 Shows Loading Indicator if name is being fetched
                      _isLoading 
                          ? const SizedBox(
                              width: 20, height: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : Text(
                              displayName, 
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              textAlign: TextAlign.center,
                            ),
                    ],
                  )),

                  const SizedBox(height: 40),

                  // Details Cards
                  _buildAnimatedItem(2, _buildDetailCard(Icons.family_restroom, "Relationship", _relation, const Color(0xFFE91E63))),
                  const SizedBox(height: 16),
                  _buildAnimatedItem(3, _buildDetailCard(Icons.phone_in_talk, "Direct Line", _phone, const Color(0xFF4CAF50))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String label, String value, Color accentColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 800),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Interval((index * 0.15).clamp(0.0, 1.0), 1.0, curve: Curves.easeOutCubic),
      builder: (context, double val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 40 * (1 - val)), child: child)),
      child: child,
    );
  }
}