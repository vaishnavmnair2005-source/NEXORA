import 'package:url_launcher/url_launcher.dart'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import '../utils/constants.dart';
import 'auth/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'patient_registration_flow.dart';
import 'patient_profile_dashboard.dart';
import 'onboarding_screen.dart'; 
import 'caregiver_profile_screen.dart'; 
import 'shimmer_loader.dart';               
import 'pdf_export_service.dart';           
import 'offline_mode_service.dart';         

class PatientDashboard extends StatefulWidget {
  final int userId;
  const PatientDashboard({super.key, required this.userId});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with TickerProviderStateMixin {
  // --- STATE ---
  bool _isLoading = true;
  bool _isDevicePaired = false;

  // Profile Data
  String _patientId = "";
  String _mrdNumber = "";
  String _firstName = "";
  String _lastName = "";
  String _dob = "";
  String _bloodGroup = "";
  String _phone = "";
  String _address = "";
  String _gender = "";
  String _email = "";
  String? _deviceId;

  // Caregiver Data
  String _cgName = "";
  String _cgRelation = "";
  String _cgPhone = "";
  dynamic _cgIsPrimary;
  String _cgUserId = "";

  // SOS State
  Timer? _sosTimer;
  int _countdown = 3;
  bool _isCountingDown = false;

  // Vitals
  Map<String, dynamic> _vitals = {
    "bpm": 0,
    "hrv": 0,
    "spo2": 0,
    "temp": 0.0,
    "gsr": "Normal",
    "fall_status": "Safe",
  };

  Timer? _dataTimer;

  // Animation Controllers
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _entranceController;
  late Animation<double> _shimmerAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _entranceFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));

    _fetchCompleteUserProfile();
    _dataTimer = Timer.periodic(const Duration(seconds: 2), (_) => _updateSimulatedSignals());
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _entranceController.dispose();
    _dataTimer?.cancel();
    _sosTimer?.cancel();
    super.dispose();
  }

  // --- API: FETCH PROFILE ---
  Future<void> _fetchCompleteUserProfile() async {
    try {
      // ✅ ADDED TIMEOUT TO PREVENT INFINITE LOADING
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/app/profile/${widget.userId}')).timeout(const Duration(seconds: 10));
      
      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _patientId = data['patient_id'] ?? "";
            _mrdNumber = data['mrd_number'] ?? "";
            _firstName = data['first_name'] ?? "";
            _lastName = data['last_name'] ?? "";
            _email = data['email'] ?? "";
            _gender = data['gender'] ?? "";
            _dob = data['dob'] ?? "";
            _bloodGroup = data['blood_group'] ?? "";
            _phone = data['contact_number'] ?? "";
            _address = data['address'] ?? "";
            
            _cgName = data['cg_full_name'] ?? "";
            _cgRelation = data['cg_relation'] ?? "";
            _cgPhone = data['cg_phone'] ?? "";
            
            _cgIsPrimary = data['cg_is_primary'];
            _cgUserId = data['user_id']?.toString() ?? "";
            _deviceId = data['device_id'];
            _isDevicePaired = _deviceId != null && _deviceId!.isNotEmpty;
            _isLoading = false;
          });
          _entranceController.forward();
        } else {
          // ✅ STOP LOADING EVEN ON ERROR
          setState(() => _isLoading = false);
          _entranceController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _entranceController.forward();
      }
    }
  }

  // --- API: PAIR DEVICE ---
  Future<void> _pairDevice(String deviceId, BuildContext dialogContext) async {
    final cleanId = deviceId.trim().toUpperCase(); 

    if (cleanId.isEmpty) return;

    final mtFormat = RegExp(r'^MT-\d{4}$');
    if (!mtFormat.hasMatch(cleanId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Text("Invalid format. Use MT-0001 style"),
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.of(dialogContext).pop();

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/app/pair-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'patient_id': _patientId, 'device_id': cleanId}),
      ).timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      
      if (response.statusCode == 200) {
        setState(() {
          _isDevicePaired = true;
          _deviceId = cleanId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text("Bio-Patch Connected Successfully"),
            ]),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        String errorMsg = "Device pairing failed";
        try {
          final body = jsonDecode(response.body);
          errorMsg = body['detail'] ?? body['message'] ?? errorMsg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(errorMsg)),
            ]),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 10),
            Text("Connection Error. Check your network."),
          ]),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // --- API: DELETE ACCOUNT ---
  Future<void> _deleteAccount() async {
    try {
      final response = await http.delete(
          Uri.parse('${ApiConstants.baseUrl}/app/delete-account/${widget.userId}')
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); 

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()), 
            (r) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete account")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Network Error")));
    }
  }

  // --- 🚨 SOS LOGIC 🚨 ---
  void _startSOSFlow() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _sosTimer?.cancel();
        _triggerSOS(); 
      }
    });
  }

  void _cancelSOS() {
    _sosTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdown = 3;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("SOS Cancelled"), backgroundColor: Colors.blueGrey),
    );
  }

  Future<void> _triggerSOS() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/app/trigger-sos/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));

      if (_cgPhone.isNotEmpty) {
        final Uri phoneUri = Uri.parse("tel:$_cgPhone");
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        }
      }

      if (mounted) {
        setState(() => _isCountingDown = false);
        _showEmergencySuccessDialog();
      }
    } catch (e) {
      setState(() => _isCountingDown = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error: SOS Failed")));
    }
  }

  void _showEmergencySuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("🚨 SOS SENT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("Your caregiver has been notified via SMS and Call. Please stay calm; help is on the way."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // --- SIMULATION ---
  void _updateSimulatedSignals() {
    if (!_isDevicePaired || !mounted) return;
    setState(() {
      _vitals['bpm'] = 72 + (DateTime.now().second % 8);
      _vitals['spo2'] = 98;
      _vitals['temp'] = 36.6;
      _vitals['hrv'] = 55 + (DateTime.now().second % 10);
      _vitals['gsr'] = "Relaxed";
      _vitals['fall_status'] = "Safe";
    });
  }

  // --- DIALOGS ---
  void _showPairingDialog() {
    final deviceIdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A1A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.15), blurRadius: 40, spreadRadius: 2)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.memory, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Pair ESP-32", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Bio-Patch Integration", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text("Patient ID", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppColors.primary, size: 16),
                        const SizedBox(width: 10),
                        Text(
                          _patientId.isNotEmpty ? _patientId : "Loading...",
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Device ID", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deviceIdCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1.5),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "e.g. MT-0001",
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 1.0),
                      prefixIcon: const Icon(Icons.developer_board, color: Colors.white38),
                      helperText: "Found on the back of your Bio-Patch",
                      helperStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.15)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.primaryGradient),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12)],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _pairDevice(deviceIdCtrl.text.trim(), ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Connect", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0505).withOpacity(0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text("Delete Account?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text(
                    "This action is irreversible. All your medical data, vitals history, and caregiver links will be permanently erased.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text("No, Keep It", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteAccount();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text("Yes, Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPatientProfile() {
    Navigator.push(
      context,
      _fadeRoute(PatientProfileDashboard(userProfile: {
        'patient_id': _patientId,
        'mrd_number': _mrdNumber,
        'first_name': _firstName,
        'last_name': _lastName,
        'email': _email,
        'dob': _dob,
        'gender': _gender,
        'contact_number': _phone,
        'address': _address,
        'device_id': _deviceId ?? '',
      })),
    );
  }

  // --- ✅ EXPORT PDF FUNCTION WITH STRICT PAIRING CHECK ---
  Future<void> _exportPdfReport() async {
    if (!_isDevicePaired || _deviceId == null || _deviceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.link_off, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text('No device paired. Please pair your Bio-Patch before exporting a report.'),
            ),
          ]),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return; 
    }

    final userProfile = {
      'patient_id': _patientId,
      'mrd_number': _mrdNumber,
      'first_name': _firstName,
      'last_name': _lastName,
      'email': _email,
      'dob': _dob,
      'gender': _gender,
      'contact_number': _phone,
      'address': _address,
      'blood_group': _bloodGroup,
      'device_id': _deviceId, 
    };

    await PdfExportService.exportAndShare(
      context: context,
      userProfile: userProfile,
      vitals: _vitals, 
    );
  }

  void _navigateToCaregiverProfile() {
    Navigator.push(
      context,
      _fadeRoute(CaregiverProfileScreen(
        userId: widget.userId, 
        userProfile: {
          'cg_full_name': _cgName,
          'cg_relation': _cgRelation,
          'cg_phone': _cgPhone,
        },
      )),
    );
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      );

  // ── MAIN BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: _isLoading
                ? const DashboardShimmer() 
                : FadeTransition(
                    opacity: _entranceFade,
                    child: SlideTransition(
                      position: _entranceSlide,
                      child: _buildBody(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ROW ──────────────────────
  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, child) => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [Colors.white60, Colors.white, AppColors.primary, Colors.white],
                stops: [
                  0.0,
                  (_shimmerAnim.value + 1.5) / 3.0 - 0.15,
                  (_shimmerAnim.value + 1.5) / 3.0,
                  1.0
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: const Text(
                "My MediTwin Dashboard",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
          color: const Color(0xFF0D0D1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          onSelected: (val) {
            if (val == 'patient') _navigateToPatientProfile();
            if (val == 'caregiver') _navigateToCaregiverProfile();
            if (val == 'pdf') _exportPdfReport();
          },
          itemBuilder: (_) => [
            _buildMenuItem(Icons.person_outline, "Patient Profile", Colors.cyanAccent, 'patient'),
            _buildMenuItem(Icons.support_agent, "Caregiver Profile", Colors.greenAccent, 'caregiver'),
            _buildMenuItem(Icons.picture_as_pdf_outlined, "Export Report", Colors.amberAccent, 'pdf'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(IconData icon, String label, Color color, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color == Colors.redAccent ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStaggered(0, _buildHeaderRow()),
          const SizedBox(height: 25),
          if (!_isDevicePaired) ...[
            _buildStaggered(1, _buildPairButton()),
            const SizedBox(height: 20),
          ],
          _buildStaggered(2, _buildFaceCard()),
          const SizedBox(height: 20),
          _buildStaggered(3, _buildDeviceStatusChip()),
          const SizedBox(height: 24),
          if (_isDevicePaired) ...[
            // ✅ ECG IS BACK
            _buildStaggered(4, _buildSectionLabel("Live ECG Stream", Icons.monitor_heart)),
            const SizedBox(height: 10),
            _buildStaggered(5, _buildECGCard()),
            const SizedBox(height: 24),
            _buildStaggered(6, _buildSectionLabel("Real-Time Vitals", Icons.dashboard)),
            const SizedBox(height: 10),
            _buildStaggered(7, _buildVitalsGrid()),
            const SizedBox(height: 24),
            
            // --- 🚨 SOS BUTTON ---
            _buildStaggered(8, _buildSOSButton()),
          ],
          if (!_isDevicePaired) ...[
            const SizedBox(height: 16),
            _buildStaggered(4, _buildUnpairedHint()),
            const SizedBox(height: 24),
            
            // --- 🚨 SOS BUTTON ---
            _buildStaggered(5, _buildSOSButton()),
          ]
        ],
      ),
    );
  }

  // ── SOS BUTTON WIDGET ──────────────────────────────────────────
  Widget _buildSOSButton() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
      child: Container(
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_isCountingDown ? Colors.red : Colors.redAccent).withOpacity(0.3),
              blurRadius: 20,
            )
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCountingDown ? Colors.red : Colors.red.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _isCountingDown ? _cancelSOS : _startSOSFlow,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isCountingDown ? Icons.close : Icons.emergency, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                _isCountingDown ? "CANCEL SOS IN $_countdown..." : "EMERGENCY SOS",
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPairButton() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
      child: GestureDetector(
        onTap: _showPairingDialog,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF00B4CC)], begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.memory, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pair Device", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5)),
                  Text("Connect your ESP-32 Bio-Patch", style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.arrow_forward_ios, color: Colors.white60, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaceCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF0A1628), Color(0xFF0D2240), Color(0xFF071429)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 30, spreadRadius: 2)],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, spreadRadius: 1)],
            ),
            child: const Icon(Icons.person, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_firstName.isNotEmpty ? _firstName : 'Patient'} $_lastName".trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildIdChip(Icons.badge_outlined, "Patient ID", _patientId.isNotEmpty ? _patientId : "Loading..."),
                const SizedBox(height: 6),
                _buildIdChip(Icons.folder_shared_outlined, "MRD No.", _mrdNumber.isNotEmpty ? _mrdNumber : "N/A"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdChip(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 5),
        Text("$label: ", style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Text(value, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildDeviceStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (_isDevicePaired ? Colors.green : Colors.orange).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (_isDevicePaired ? Colors.green : Colors.orange).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: _isDevicePaired ? Colors.greenAccent : Colors.orange),
          const SizedBox(width: 10),
          Text(
            _isDevicePaired ? "Bio-Patch Online · ${_deviceId ?? ''}" : "No Device Paired · Tap 'Pair Device' above",
            style: TextStyle(color: _isDevicePaired ? Colors.greenAccent : Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ✅ ECG CARD IS BACK
  Widget _buildECGCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.05), blurRadius: 20)],
          ),
          child: Stack(
            children: [
              const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(20)), child: MiniECGWave()),
              Positioned(
                top: 10,
                left: 14,
                child: Row(children: [
                  const _StatusDot(color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  const Text("LIVE", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsGrid() {
    final vitals = [
      _VitalInfo("Heart Rate", "${_vitals['bpm']}", "BPM", Icons.favorite_rounded, const Color(0xFFFF4F6B)),
      _VitalInfo("SpO₂", "${_vitals['spo2']}", "%", Icons.water_drop_rounded, const Color(0xFF4FC3F7)),
      _VitalInfo("Temperature", "${_vitals['temp']}", "°C", Icons.thermostat_rounded, const Color(0xFFFFB347)),
      _VitalInfo("HRV", "${_vitals['hrv']}", "ms", Icons.graphic_eq_rounded, const Color(0xFFB39DDB)),
      _VitalInfo("Stress (GSR)", "${_vitals['gsr']}", "", Icons.psychology_rounded, const Color(0xFF4DB6AC)),
      _VitalInfo("Fall Detect", "${_vitals['fall_status']}", "", Icons.directions_run_rounded, _vitals['fall_status'] == "Safe" ? const Color(0xFF81C784) : Colors.redAccent),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vitals.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.25),
      itemBuilder: (_, i) => _buildVitalCard(vitals[i]),
    );
  }

  Widget _buildVitalCard(_VitalInfo info) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [info.color.withOpacity(0.08), Colors.black.withOpacity(0.3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: info.color.withOpacity(0.25), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: info.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(info.icon, color: info.color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(info.title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.value, style: TextStyle(color: info.color, fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
                    if (info.unit.isNotEmpty) Text(info.unit, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnpairedHint() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              Icon(Icons.sensors_off_rounded, color: Colors.white.withOpacity(0.15), size: 48),
              const SizedBox(height: 14),
              const Text("No Vitals Data", style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "Pair your ESP-32 Bio-Patch above to begin\nreal-time health monitoring.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(text.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildStaggered(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + index * 100),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (_, val, c) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: c)),
      child: child,
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (_, __) => CustomPaint(painter: _BackgroundPainter(_particleController.value), size: Size.infinite),
    );
  }
}

class _VitalInfo {
  final String title, value, unit;
  final IconData icon;
  final Color color;
  _VitalInfo(this.title, this.value, this.unit, this.icon, this.color);
}

class _StatusDot extends StatefulWidget {
  final Color color;
  const _StatusDot({required this.color});
  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 16 * _c.value,
          height: 16 * _c.value,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withOpacity(1 - _c.value), width: 1.5)),
        ),
      ),
      Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    ]);
  }
}

class _BackgroundPainter extends CustomPainter {
  final double t;
  _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..shader = const RadialGradient(center: Alignment.topCenter, radius: 1.4, colors: [Color(0xFF050D1F), Color(0xFF000000)], stops: [0.0, 0.9]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orb1 = Paint()..shader = RadialGradient(colors: [const Color(0xFF00E5FF).withOpacity(0.06), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.15 + 30 * math.sin(t * 2 * math.pi)), radius: 200));
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.15 + 30 * math.sin(t * 2 * math.pi)), 200, orb1);

    final orb2 = Paint()..shader = RadialGradient(colors: [const Color(0xFF0D47A1).withOpacity(0.1), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.6 + 20 * math.cos(t * 2 * math.pi)), radius: 250));
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.6 + 20 * math.cos(t * 2 * math.pi)), 250, orb2);

    final gridPaint = Paint()..color = Colors.white.withOpacity(0.025)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += 60) canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
  }
  @override
  bool shouldRepaint(_BackgroundPainter old) => true;
}

// ✅ ECG ANIMATION LOGIC IS BACK
class MiniECGWave extends StatefulWidget {
  const MiniECGWave({super.key});
  @override
  State<MiniECGWave> createState() => _MiniECGWaveState();
}

class _MiniECGWaveState extends State<MiniECGWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (_, __) => CustomPaint(painter: _ECGPainter(_controller.value), size: Size.infinite));
  }
}

class _ECGPainter extends CustomPainter {
  final double progress;
  _ECGPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()..color = Colors.greenAccent.withOpacity(0.15)..strokeWidth = 6.0..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final linePaint = Paint()..color = Colors.greenAccent..strokeWidth = 1.8..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double midY = size.height / 2;
    const double cycleWidth = 200.0;
    final int cycles = (size.width / cycleWidth).ceil() + 2;
    final double startX = -(progress * cycleWidth);

    path.moveTo(startX, midY);
    for (int i = 0; i < cycles; i++) {
      double x = startX + (i * cycleWidth);
      path.lineTo(x + 30, midY); path.lineTo(x + 40, midY - 10); path.lineTo(x + 50, midY); path.lineTo(x + 60, midY + 10);
      path.lineTo(x + 70, midY - 45); path.lineTo(x + 80, midY + 22); path.lineTo(x + 90, midY); path.lineTo(x + 120, midY);
      path.lineTo(x + 140, midY - 16); path.lineTo(x + 160, midY); path.lineTo(x + cycleWidth, midY);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }
  @override
  bool shouldRepaint(_ECGPainter old) => true;
}