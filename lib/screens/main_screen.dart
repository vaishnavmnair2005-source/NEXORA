import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'patient_dashboard.dart';
import 'health_trends_screen.dart';
import 'settings_screen.dart';
import 'medication_screen.dart'; // ✅ Ensures Medication Screen is imported
import 'splash_screen.dart'; // For navigation on DB missing user

class MainScreen extends StatefulWidget {
  final int userId;
  const MainScreen({super.key, required this.userId});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _pageIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  // Profile is fetched once here so SettingsScreen can use it immediately
  Map<String, dynamic> _userProfile = {};
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileForSettings();
  }

  Future<void> _fetchProfileForSettings() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/app/profile/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // ✅ Success: Load the profile normally
        setState(() {
          _userProfile = Map<String, dynamic>.from(jsonDecode(response.body));
          _profileLoaded = true;
        });
      } 
      else if (response.statusCode == 404) {
        // 🚨 DB Missing User: The database data was deleted!
        // Clear local memory and send them back to the start screen.
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const SplashScreen()) // Add import 'splash_screen.dart'; at the top if needed
        );
      } 
      else {
        // ⚠️ Other error: Just stop the loading circle so the app doesn't freeze
        setState(() => _profileLoaded = true);
      }
    } catch (_) {
      // 📶 Network error: Stop the loading circle
      if (mounted) setState(() => _profileLoaded = true);
    }
  }

  // ✅ UPDATED: The 3rd item is now definitely your MedicationScreen
  List<Widget> get _pages => [
        PatientDashboard(userId: widget.userId),
        HealthTrendsScreen(userId: widget.userId),
        MedicationScreen(userId: widget.userId), // <--- Active Medication Screen
        _profileLoaded
            ? SettingsScreen(userId: widget.userId, userProfile: _userProfile)
            : const _LoadingTab(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ── Body — always use IndexedStack so pages keep their state ───────
      body: IndexedStack(
        index: _pageIndex,
        children: _pages,
      ),

      // ── Bottom nav — always present as long as MainScreen is on screen ──
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: _pageIndex,
        height: 60.0,
        items: const <Widget>[
          Icon(Icons.dashboard_customize, size: 30, color: Colors.white),
          Icon(Icons.show_chart,           size: 30, color: Colors.white),
          Icon(Icons.medication,           size: 30, color: Colors.white),
          Icon(Icons.settings,             size: 30, color: Colors.white),
        ],
        color: const Color(0xFF1A1A1A),
        buttonBackgroundColor: AppColors.primary,
        backgroundColor: Colors.black,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: (index) {
          setState(() => _pageIndex = index);
          // Re-fetch profile every time the Settings tab is opened so that
          // newly paired devices (or any profile changes) are reflected at once.
          if (index == 3) _fetchProfileForSettings();
        },
      ),
    );
  }
}

// ── Loading placeholder while profile is fetched ─────────────────────────────
class _LoadingTab extends StatelessWidget {
  const _LoadingTab();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}