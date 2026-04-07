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
import 'package:meditwin/widgets/ecg_wave.dart';

class PatientDashboard extends StatefulWidget {
  final int userId;
  const PatientDashboard({super.key, required this.userId});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // --- STATE ---
  bool _isLoading = true;
  bool _isDevicePaired = false;
  DateTime _lastUpdated = DateTime.now();

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

  // ECG IP State
  final TextEditingController _ecgIpController = TextEditingController();
  String? _activeEcgIp;            // null = not connected yet
  bool _ecgIsConnected = false;    // reported back by ECGWave widget
  bool _ecgEverConnected = false;  // true once we get the first confirmed connection

  // Vitals
  Map<String, dynamic> _vitals = {
    "bpm": 0,
    "spo2": 0,
    "temp": 0.0,
    "hrv_rmssd": 0,
    "hrv_sdnn": 0,
    "hrv_pnn50": 0.0,
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

    WidgetsBinding.instance.addObserver(this);

    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _entranceFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _entranceSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));

    _fetchCompleteUserProfile();
    _loadSavedEcgIp();

    // 🚨 CONTINUOUS RADAR LOOP: Checks database every 2 seconds
    _dataTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchRealVitals());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shimmerController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _entranceController.dispose();
    _dataTimer?.cancel();
    _sosTimer?.cancel();
    _ecgIpController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _dataTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() => _isLoading = true);
        _fetchCompleteUserProfile();
        _dataTimer?.cancel();
        _dataTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchRealVitals());
      }
    }
  }

  // --- ECG IP HELPERS ---

  /// Loads the last-used ESP32 IP from SharedPreferences on startup.
  Future<void> _loadSavedEcgIp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('ecg_ip') ?? '';
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _ecgIpController.text = saved;
        _activeEcgIp = saved;
      });
    }
  }

  /// Called when user taps the Connect button.
  Future<void> _connectEcg() async {
    final ip = _ecgIpController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Text('Please enter the ESP32 IP address'),
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    // Save for next launch
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ecg_ip', ip);

    setState(() {
      _activeEcgIp = ip;
      _ecgIsConnected = false;   // will be updated by ECGWave callback
      _ecgEverConnected = false; // fresh attempt
    });
  }

  /// Called when the user taps "Disconnect" while already connected.
  Future<void> _disconnectEcg() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ecg_ip');
    setState(() {
      _activeEcgIp = null;
      _ecgIsConnected = false;
      _ecgEverConnected = false;
      _ecgIpController.clear();
    });
  }

  // --- API: FETCH PROFILE ---
  Future<void> _fetchCompleteUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/app/profile/${widget.userId}')
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
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
        }
      } else if (response.statusCode == 404) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (r) => false,
          );
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _entranceController.forward();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Server Error: ${response.statusCode}. Check Python terminal."),
              backgroundColor: Colors.redAccent,
            )
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _entranceController.forward();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Network Error: Connection Timed Out. Check your IP address in constants.dart")),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          )
        );
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
      );

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
          Uri.parse('${ApiConstants.baseUrl}/app/delete-account/${widget.userId}'));

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

  // --- SOS LOGIC ---
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
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/app/trigger-sos/${widget.userId}'),
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network Error: SOS Failed")));
    }
  }

  void _showEmergencySuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("🚨 SOS SENT",
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
            "Your caregiver has been notified via SMS and Call. Please stay calm; help is on the way."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // 🚨 SAFE DATA FETCHING: Prevents crashes if Postgres sends weird string formats
  Future<void> _fetchRealVitals() async {
    if (!_isDevicePaired || !mounted) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/vitals/latest/${widget.userId}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _lastUpdated = DateTime.now();
          _vitals['bpm']         = int.tryParse(data['bpm'].toString()) ?? _vitals['bpm'];
          _vitals['spo2']        = int.tryParse(data['spo2'].toString()) ?? _vitals['spo2'];
          _vitals['temp']        = double.tryParse(data['temp'].toString()) ?? _vitals['temp'];
          _vitals['hrv_rmssd']   = double.tryParse(data['hrv_rmssd'].toString()) ?? _vitals['hrv_rmssd'];
          _vitals['hrv_sdnn']    = double.tryParse(data['hrv_sdnn'].toString()) ?? _vitals['hrv_sdnn'];
          _vitals['hrv_pnn50']   = double.tryParse(data['hrv_pnn50'].toString()) ?? _vitals['hrv_pnn50'];
          _vitals['fall_status'] = data['fall_status'] ?? 'Safe';
        });
      }
    } catch (e) {
      print("Vitals Fetch Error: $e");
    }
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
                          Text("Pair ESP-32",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Bio-Patch Integration",
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text("Patient ID",
                      style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
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
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Device ID",
                      style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child:
                              const Text("Cancel", style: TextStyle(color: Colors.white54)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient:
                                const LinearGradient(colors: AppColors.primaryGradient),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12)
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () =>
                                _pairDevice(deviceIdCtrl.text.trim(), ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text("Connect",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
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

  Future<void> _exportPdfReport() async {
    if (!_isDevicePaired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.link_off, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      "Please connect your ESP-32 Bio-Patch to generate a report.")),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
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
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      );

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_cloudy_rounded;
    return Icons.nightlight_round;
  }

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

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, child) => ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: const [
                  Colors.white60,
                  Colors.white,
                  AppColors.primary,
                  Colors.white
                ],
                stops: [
                  0.0,
                  (_shimmerAnim.value + 1.5) / 3.0 - 0.15,
                  (_shimmerAnim.value + 1.5) / 3.0,
                  1.0
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: Row(
                children: [
                  Icon(_getGreetingIcon(), color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${_getGreeting()}, ${_firstName.isNotEmpty ? _firstName : 'Patient'}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
            _buildMenuItem(Icons.person_outline, "Patient Profile",
                Colors.cyanAccent, 'patient'),
            _buildMenuItem(Icons.support_agent, "Caregiver Profile",
                Colors.greenAccent, 'caregiver'),
            _buildMenuItem(Icons.picture_as_pdf_outlined, "Export Report",
                Colors.amberAccent, 'pdf'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      IconData icon, String label, Color color, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: color == Colors.redAccent
                      ? Colors.redAccent
                      : Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
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
            _buildStaggered(4, _buildSectionLabel("Live ECG Stream", Icons.monitor_heart)),
            const SizedBox(height: 10),
            _buildStaggered(5, _buildECGCard()),
            const SizedBox(height: 24),
            _buildStaggered(6, _buildSectionLabelWithTime("Real-Time Vitals", Icons.dashboard)),
            const SizedBox(height: 12),
            _buildStaggered(7, _buildAIAssessmentBanner()),
            const SizedBox(height: 16),
            _buildStaggered(8, _buildVitalsGrid()),
            const SizedBox(height: 24),
            _buildStaggered(9, _buildSOSButton()),
          ],
          if (!_isDevicePaired) ...[
            const SizedBox(height: 16),
            _buildStaggered(4, _buildUnpairedHint()),
            const SizedBox(height: 24),
            _buildStaggered(5, _buildSOSButton()),
          ]
        ],
      ),
    );
  }

  Widget _buildAIAssessmentBanner() {
    bool isAbnormal = _vitals['bpm'] > 95 ||
        _vitals['temp'] > 37.5 ||
        _vitals['spo2'] < 95 ||
        _vitals['fall_status'] == "Fall Detected";
    Color statusColor = isAbnormal ? Colors.orangeAccent : Colors.greenAccent;
    IconData statusIcon = isAbnormal
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline_rounded;
    String statusText = isAbnormal
        ? "System Assessment: Some vitals are currently outside normal ranges."
        : "System Assessment: All vitals are within normal parameters.";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

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
              color:
                  (_isCountingDown ? Colors.red : Colors.redAccent).withOpacity(0.3),
              blurRadius: 20,
            )
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isCountingDown ? Colors.red : Colors.red.shade900,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _isCountingDown ? _cancelSOS : _startSOSFlow,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isCountingDown ? Icons.close : Icons.emergency,
                  color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                _isCountingDown
                    ? "CANCEL SOS IN $_countdown..."
                    : "EMERGENCY SOS",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
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
            gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF00B4CC)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.memory, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Pair Device",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 0.5)),
                  Text("Connect your ESP-32 Bio-Patch",
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
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
            gradient: const LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF0D2240), Color(0xFF071429)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: 2)
            ],
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
              gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1)
              ],
            ),
            child: const Icon(Icons.person, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_firstName.isNotEmpty ? _firstName : 'Patient'} $_lastName"
                      .trim(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildIdChip(Icons.badge_outlined, "Patient ID",
                    _patientId.isNotEmpty ? _patientId : "Loading..."),
                const SizedBox(height: 6),
                _buildIdChip(Icons.folder_shared_outlined, "MRD No.",
                    _mrdNumber.isNotEmpty ? _mrdNumber : "N/A"),
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
        Text(value,
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildDeviceStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (_isDevicePaired ? Colors.green : Colors.orange).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (_isDevicePaired ? Colors.green : Colors.orange).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: _isDevicePaired ? Colors.greenAccent : Colors.orange),
          const SizedBox(width: 10),
          Text(
            _isDevicePaired
                ? "Bio-Patch Online · ${_deviceId ?? ''}"
                : "No Device Paired · Tap 'Pair Device' above",
            style: TextStyle(
                color: _isDevicePaired ? Colors.greenAccent : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildECGCard() {
    final bool hasIp = _activeEcgIp != null && _activeEcgIp!.isNotEmpty;

    // Status derives from three distinct states:
    //   1. No IP entered                → idle (white38)
    //   2. IP set, awaiting first conn  → connecting (amber)
    //   3. Confirmed connected          → live (greenAccent)
    //   4. Was connected, now dropped   → signal lost (redAccent)
    final Color statusColor;
    final String statusLabel;
    if (!hasIp) {
      statusColor = Colors.white38;
      statusLabel = 'ENTER IP';
    } else if (_ecgIsConnected) {
      statusColor = Colors.greenAccent;
      statusLabel = 'LIVE';
    } else if (_ecgEverConnected) {
      // Had a confirmed connection, now dropped
      statusColor = Colors.redAccent;
      statusLabel = 'SIGNAL LOST';
    } else {
      // IP entered but not yet confirmed — still attempting
      statusColor = Colors.amberAccent;
      statusLabel = 'CONNECTING…';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top bar: status dot + label ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _StatusDot(color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              // ── ECG waveform area ────────────────────────────────────
              SizedBox(
                height: 60,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: ECGWave(
                    ip: _activeEcgIp,
                    color: Colors.greenAccent,
                    onConnectionChanged: (connected) {
                      if (mounted) {
                        setState(() {
                          _ecgIsConnected = connected;
                          if (connected) _ecgEverConnected = true;
                        });
                      }
                    },
                  ),
                ),
              ),

              // ── IP input + smart button row ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: Row(
                  children: [
                    // IP text field — read-only while actively connected
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _ecgIpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          readOnly: _ecgIsConnected,
                          style: TextStyle(
                            color: _ecgIsConnected ? Colors.white54 : Colors.white,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ESP32 IP  e.g. 192.168.1.50',
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                            prefixIcon: Icon(
                              Icons.router_outlined,
                              color: _ecgIsConnected ? Colors.white30 : Colors.greenAccent,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: _ecgIsConnected
                                ? Colors.white.withOpacity(0.02)
                                : Colors.white.withOpacity(0.05),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.greenAccent.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _ecgIsConnected
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.greenAccent.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.greenAccent, width: 1.2),
                            ),
                          ),
                          onSubmitted: _ecgIsConnected ? null : (_) => _connectEcg(),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Smart button: Connect → Connecting… → Disconnect
                    SizedBox(
                      height: 40,
                      child: _ecgIsConnected
                          // ── DISCONNECT ───────────────────────────────
                          ? ElevatedButton.icon(
                              onPressed: _disconnectEcg,
                              icon: const Icon(Icons.wifi_off, size: 16, color: Colors.white),
                              label: const Text(
                                'Disconnect',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            )
                          : hasIp && !_ecgEverConnected
                              // ── CONNECTING… (spinner) ────────────────
                              ? ElevatedButton.icon(
                                  onPressed: _disconnectEcg, // tap to cancel/retry
                                  icon: const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: Colors.black,
                                    ),
                                  ),
                                  label: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amberAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                )
                              // ── CONNECT (idle / after disconnect) ────
                              : ElevatedButton.icon(
                                  onPressed: _connectEcg,
                                  icon: const Icon(Icons.wifi_tethering,
                                      size: 16, color: Colors.black),
                                  label: const Text(
                                    'Connect',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚨 TASK 1 FORMATTING: Formats empty 0 values to '--'
  Widget _buildVitalsGrid() {
    String formatVital(dynamic value) {
      if (value == null || value == 0 || value == 0.0) return "--";
      return value.toString();
    }

    final vitals = [
      _VitalInfo("Heart Rate", formatVital(_vitals['bpm']), "BPM",
          Icons.favorite_rounded, const Color(0xFFFF4F6B)),
      _VitalInfo("SpO₂", formatVital(_vitals['spo2']), "%",
          Icons.water_drop_rounded, const Color(0xFF4FC3F7)),
      _VitalInfo("Temperature", formatVital(_vitals['temp']), "°C",
          Icons.thermostat_rounded, const Color(0xFFFFB347)),
      _VitalInfo("HRV Analytics", "", "", Icons.graphic_eq_rounded,
          const Color(0xFFB39DDB), subMetrics: {
        "RMSSD": _vitals['hrv_rmssd'] == 0 || _vitals['hrv_rmssd'] == 0.0 ? "--" : "${_vitals['hrv_rmssd']} ms",
        "SDNN": _vitals['hrv_sdnn'] == 0 || _vitals['hrv_sdnn'] == 0.0 ? "--" : "${_vitals['hrv_sdnn']} ms",
        "pNN50": _vitals['hrv_pnn50'] == 0 || _vitals['hrv_pnn50'] == 0.0 ? "--" : "${_vitals['hrv_pnn50']}%",
      }),
      _VitalInfo(
          "Fall Detect",
          _vitals['fall_status'] == "Safe" || _vitals['fall_status'] == null ? "Safe" : "${_vitals['fall_status']}",
          "",
          Icons.directions_run_rounded,
          _vitals['fall_status'] == "Safe" || _vitals['fall_status'] == null
              ? const Color(0xFF81C784)
              : Colors.redAccent),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vitals.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25),
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
            gradient: LinearGradient(
                colors: [
                  info.color.withOpacity(0.08),
                  Colors.black.withOpacity(0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
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
                      decoration: BoxDecoration(
                          color: info.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(info.icon, color: info.color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(info.title,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
                if (info.subMetrics != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: info.subMetrics!.entries
                            .map((e) => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.key,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    Text(e.value,
                                        style: TextStyle(
                                            color: info.color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ))
                            .toList(),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.value,
                          style: TextStyle(
                              color: info.color,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      if (info.unit.isNotEmpty && info.value != "--")
                        Text(info.unit,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
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
              Icon(Icons.sensors_off_rounded,
                  color: Colors.white.withOpacity(0.15), size: 48),
              const SizedBox(height: 14),
              const Text("No Vitals Data",
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "Pair your ESP-32 Bio-Patch above to begin\nreal-time health monitoring.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white24, fontSize: 13, height: 1.5),
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
        Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildSectionLabelWithTime(String text, IconData icon) {
    final timeStr =
        "${_lastUpdated.hour.toString().padLeft(2, '0')}:${_lastUpdated.minute.toString().padLeft(2, '0')}:${_lastUpdated.second.toString().padLeft(2, '0')}";

    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const Spacer(),
        Text("Last synced: $timeStr",
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStaggered(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + index * 100),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (_, val, c) => Opacity(
          opacity: val,
          child:
              Transform.translate(offset: Offset(0, 20 * (1 - val)), child: c)),
      child: child,
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (_, __) => CustomPaint(
          painter: _BackgroundPainter(_particleController.value),
          size: Size.infinite),
    );
  }
}

class _VitalInfo {
  final String title, value, unit;
  final IconData icon;
  final Color color;
  final Map<String, String>? subMetrics;

  _VitalInfo(this.title, this.value, this.unit, this.icon, this.color,
      {this.subMetrics});
}

class _StatusDot extends StatefulWidget {
  final Color color;
  const _StatusDot({required this.color});
  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: widget.color.withOpacity(1 - _c.value), width: 1.5)),
        ),
      ),
      Container(
          width: 6,
          height: 6,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    ]);
  }
}

class _BackgroundPainter extends CustomPainter {
  final double t;
  _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [Color(0xFF050D1F), Color(0xFF000000)],
              stops: [0.0, 0.9])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orb1 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF00E5FF).withOpacity(0.06),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.8,
              size.height * 0.15 + 30 * math.sin(t * 2 * math.pi)),
          radius: 200));
    canvas.drawCircle(
        Offset(size.width * 0.8,
            size.height * 0.15 + 30 * math.sin(t * 2 * math.pi)),
        200,
        orb1);

    final orb2 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF0D47A1).withOpacity(0.1),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.1,
              size.height * 0.6 + 20 * math.cos(t * 2 * math.pi)),
          radius: 250));
    canvas.drawCircle(
        Offset(size.width * 0.1,
            size.height * 0.6 + 20 * math.cos(t * 2 * math.pi)),
        250,
        orb2);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += 60)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => true;
}

class MiniECGWave extends StatefulWidget {
  const MiniECGWave({super.key});
  @override
  State<MiniECGWave> createState() => _MiniECGWaveState();
}

class _MiniECGWaveState extends State<MiniECGWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
            painter: _ECGPainter(_controller.value), size: Size.infinite));
  }
}

class _ECGPainter extends CustomPainter {
  final double progress;
  _ECGPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.15)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double midY = size.height / 2;
    const double cycleWidth = 200.0;
    final int cycles = (size.width / cycleWidth).ceil() + 2;
    final double startX = -(progress * cycleWidth);

    path.moveTo(startX, midY);
    for (int i = 0; i < cycles; i++) {
      double x = startX + (i * cycleWidth);
      path.lineTo(x + 30, midY);
      path.lineTo(x + 40, midY - 10);
      path.lineTo(x + 50, midY);
      path.lineTo(x + 60, midY + 10);
      path.lineTo(x + 70, midY - 45);
      path.lineTo(x + 80, midY + 22);
      path.lineTo(x + 90, midY);
      path.lineTo(x + 120, midY);
      path.lineTo(x + 140, midY - 16);
      path.lineTo(x + 160, midY);
      path.lineTo(x + cycleWidth, midY);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_ECGPainter old) => true;
}