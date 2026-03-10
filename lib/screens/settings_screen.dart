import 'splash_screen.dart'; // ✅ Required for navigation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // ✅ for email, form, store
import 'dart:ui';
import '../utils/constants.dart';
import 'biometric_lock.dart';
import 'legal_document_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> userProfile;

  const SettingsScreen({
    super.key,
    required this.userId,
    required this.userProfile,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _biometricEnabled = false;
  bool _sosAlertsEnabled = true;
  bool _vitalAlertsEnabled = true;
  bool _dailySummaryEnabled = false;
  bool _isLoading = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entranceController, curve: Curves.easeOutCubic));
    _loadPreferences();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final available = await BiometricLockService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        _sosAlertsEnabled = prefs.getBool('sos_alerts') ?? true;
        _vitalAlertsEnabled = prefs.getBool('vital_alerts') ?? true;
        _dailySummaryEnabled = prefs.getBool('daily_summary') ?? false;
        _biometricAvailable = available;
      });
    }
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await BiometricLockService.authenticate(
          reason: 'Confirm identity to enable biometric lock');
      if (!ok) return;
    }
    setState(() => _biometricEnabled = value);
    await _savePref('biometric_enabled', value);
    _showSnack(
      value ? 'Biometric lock enabled' : 'Biometric lock disabled',
      value ? Colors.green : Colors.orange,
      Icons.fingerprint,
    );
  }

  void _showSnack(String msg, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── TWO-STEP DELETE ACCOUNT ───────────────────────────────────────────────
  Future<void> _showDeleteAccountDialog() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
          child:
              const Icon(Icons.delete_forever, color: Colors.red, size: 36),
        ),
        title: const Text('Delete Account?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'This will permanently erase everything:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 14),
          ...[
            'All vitals & ECG history',
            'Medical information',
            'Caregiver relationships',
            'Device pairing data',
          ].map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.close, color: Colors.redAccent, size: 15),
                  const SizedBox(width: 8),
                  Text(item,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13)),
                ]),
              )),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.amber, size: 15),
              SizedBox(width: 8),
              Expanded(
                  child: Text('This action cannot be undone.',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Account',
                  style: TextStyle(color: AppColors.primary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Delete',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (step1 != true) return;

    // Step 2 — type DELETE
    final confirmCtrl = TextEditingController();
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Final Confirmation',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Type  DELETE  to permanently remove your account:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 14),
          TextField(
            controller: confirmCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2),
            decoration: InputDecoration(
              hintText: 'Type DELETE',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 1.5)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (confirmCtrl.text.trim().toUpperCase() == 'DELETE') {
                  Navigator.pop(ctx, true);
                } else {
                  _showSnack('Type DELETE exactly to confirm',
                      Colors.red, Icons.error_outline);
                }
              },
              child: const Text('Delete Forever',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (step2 != true) return;

    setState(() => _isLoading = true);
    try {
      // ✅ Added a timeout so the app NEVER buffers forever again
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/app/delete-account/${widget.userId}')
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
          // ✅ FIXED NAVIGATION: Goes directly to the Splash Screen to reboot the app
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SplashScreen()),
            (route) => false,
          );
        }
      } else {
        _showSnack('Failed to delete. Try again.', Colors.red, Icons.error_outline);
      }
    } catch (_) {
      // ✅ If the IP is wrong, it will fail after 10 seconds and show this error instead of buffering forever
      _showSnack('Network error. Check server connection.', Colors.red, Icons.wifi_off);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── CHANGE PASSWORD SHEET ─────────────────────────────────────────────────
  void _showChangePasswordSheet() {
    final curCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final conCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to move up
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        // ✅ FIX 1: Use 'ctx' instead of 'context' so it perfectly detects the keyboard height
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        // ✅ FIX 2: Wrap in a SingleChildScrollView so the fields can scroll when pushed up
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            decoration: const BoxDecoration(
              color: Color(0xFF0A1628),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Change Password',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _pwField(curCtrl, 'Current Password', Icons.lock_outline),
                const SizedBox(height: 12),
                _pwField(newCtrl, 'New Password', Icons.lock_open_outlined),
                const SizedBox(height: 12),
                _pwField(conCtrl, 'Confirm New Password',
                    Icons.lock_reset_outlined),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      if (newCtrl.text != conCtrl.text) {
                        _showSnack('Passwords do not match', Colors.red,
                            Icons.error_outline);
                        return;
                      }
                      Navigator.pop(ctx);
                      _showSnack('Password updated successfully', Colors.green,
                          Icons.check_circle);
                    },
                    child: const Text('Update Password',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pwField(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  // ── CONTACT SUPPORT — opens Gmail compose ────────────────────────────────
  Future<void> _launchSupportEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'teamnexora2026@gmail.com',
      queryParameters: {
        'subject': 'NEXORA MediTwin Support Request',
        'body': 'Hi NEXORA Support,\n\nUser ID: ${widget.userId}\n\nIssue:\n',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showSnack('Could not open email app', Colors.red, Icons.error_outline);
    }
  }

  // ── RATE THE APP — 5-star dialog ─────────────────────────────────────────
  void _showRatingDialog() {
    int _selectedStars = 0;
    const messages = [
      '',
      'We\'re sorry to hear that. We\'ll do better! 😔',
      'Thanks for the feedback. We\'re improving! 🙏',
      'Glad you like it! We\'ll keep going 😊',
      'That\'s great! Thank you so much! 🌟',
      'Amazing! You made our day! 🎉 Thank you!',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 44),
            SizedBox(height: 8),
            Text('Rate NEXORA MediTwin',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('How would you rate your experience?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setInner(() => _selectedStars = star),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      _selectedStars >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: _selectedStars >= star ? 44 : 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedStars > 0
                  ? Container(
                      key: ValueKey(_selectedStars),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Text(
                        messages[_selectedStars],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    )
                  : const SizedBox(height: 40),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _selectedStars == 0
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _showSnack(
                          '$_selectedStars star${_selectedStars > 1 ? 's' : ''} — thank you for your valuable rating! ⭐',
                          Colors.amber, Icons.star_rounded);
                    },
              child: const Text('Submit Rating', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── REPORT A BUG — opens Google Form ─────────────────────────────────────
  // 📌 Replace the URL below with your actual Google Form link.
  // Create at forms.google.com and set response email to teamnexora2026@gmail.com
  static const String _bugFormUrl =
      "https://forms.gle/ZmqEcrSBNFtgDp9x7";

  Future<void> _launchBugReportForm() async {
    final uri = Uri.parse(_bugFormUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open bug report form', Colors.red, Icons.error_outline);
    }
  }

  // ── FAQ SHEET ─────────────────────────────────────────────────────────────
  void _showFaqSheet() {
    const faqs = [
      ('How do I pair my Bio-Patch?',
          'Tap "Pair Bio-Patch" on the Dashboard, enter your Patient ID and the device ID on the back of the device (format: MT-0001).'),
      ('How accurate are the vital readings?',
          'The ESP-32 Bio-Patch has ±2% accuracy for SpO₂, ±1 bpm for heart rate, and ±0.2°C for temperature under standard conditions.'),
      ('What triggers an SOS alert?',
          'Tap the SOS button on the Dashboard. A 3-second countdown gives you a chance to cancel before the alert is sent to your caregiver.'),
      ('Can my doctor see my data?',
          'Data is private by default. Use ⋮ → Export Report to generate a PDF to share with your healthcare provider.'),
      ('How do I update my caregiver info?',
          'Tap ⋮ on the Dashboard → Caregiver Profile to view. Contact support to update caregiver details.'),
      ('Is my health data secure?',
          'Yes. All data is AES-256 encrypted at rest and secured with TLS 1.3 in transit. We are HIPAA compliant.'),
      ('How do I export my health report?',
          'On the Dashboard, tap ⋮ (three dots) → Export Report to generate and share a PDF of your current health data.'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0A1628),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Row(children: [
            Icon(Icons.quiz_outlined, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('Help & FAQs',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: faqs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final (q, a) = faqs[i];
                return _FaqTile(question: q, answer: a);
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── ABOUT DIALOG ──────────────────────────────────────────────────────────
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.health_and_safety,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 14),
          const Text('NEXORA MediTwin',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text('Version 1.0.0 (Build 42)',
              style:
                  TextStyle(color: AppColors.primary, fontSize: 12)),
          const SizedBox(height: 14),
          const Text(
              'Where Intelligence Meets Humanity.\nBuilt with ♥ by NEXORA Technologies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.6)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(children: [
              _aRow('Platform', 'MediTwin Digital Health'),
              _aRow('Stack', 'Flutter 3.x + FastAPI'),
              _aRow('Device', 'ESP-32 Bio-Patch'),
              _aRow('Security', 'AES-256 · TLS 1.3'),
              _aRow('Compliance', 'HIPAA · GDPR'),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close',
                  style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  Widget _aRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(k,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const Spacer(),
        Text(v,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final first = widget.userProfile['first_name'] ?? '';
    final last = widget.userProfile['last_name'] ?? '';
    final email = widget.userProfile['email'] ?? '';
    final patientId = widget.userProfile['patient_id'] ?? 'N/A';
    final deviceId = widget.userProfile['device_id'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.6,
                colors: [Color(0xFF0D1B3E), Color(0xFF000000)],
              ),
            ),
          ),
          Positioned.fill(
              child: Opacity(
                  opacity: 0.025,
                  child: CustomPaint(painter: _GridPainter()))),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(children: [
                        _iconBtn(Icons.arrow_back_ios_new,
                            () => Navigator.pop(context)),
                        const SizedBox(width: 14),
                        const Text('Settings',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ]),

                      const SizedBox(height: 22),
                      _profileCard(first, last, email, patientId, deviceId),

                      const SizedBox(height: 26),
                      _label('Security & Access', Icons.shield_outlined),
                      const SizedBox(height: 10),
                      _card([
                        _toggle(
                          icon: Icons.fingerprint,
                          color: AppColors.primary,
                          title: 'Biometric Lock',
                          sub: _biometricAvailable
                              ? 'Fingerprint / Face ID on open'
                              : 'Not available on this device',
                          val: _biometricEnabled && _biometricAvailable,
                          enabled: _biometricAvailable,
                          onChange: _toggleBiometric,
                        ),
                        _div(),
                        _tap(
                            icon: Icons.lock_reset_outlined,
                            color: Colors.cyanAccent,
                            title: 'Change Password',
                            sub: 'Update your account password',
                            onTap: _showChangePasswordSheet),
                      ]),

                      const SizedBox(height: 20),
                      _label('Notifications', Icons.notifications_outlined),
                      const SizedBox(height: 10),
                      _card([
                        _toggle(
                          icon: Icons.sos_rounded,
                          color: Colors.redAccent,
                          title: 'SOS Emergency Alerts',
                          sub: 'Caregiver call & SMS on SOS',
                          val: _sosAlertsEnabled,
                          enabled: true,
                          onChange: (v) {
                            setState(() => _sosAlertsEnabled = v);
                            _savePref('sos_alerts', v);
                          },
                        ),
                        _div(),
                        _toggle(
                          icon: Icons.monitor_heart_outlined,
                          color: Colors.pinkAccent,
                          title: 'Vital Anomaly Alerts',
                          sub: 'Alert when readings go out of range',
                          val: _vitalAlertsEnabled,
                          enabled: true,
                          onChange: (v) {
                            setState(() => _vitalAlertsEnabled = v);
                            _savePref('vital_alerts', v);
                          },
                        ),
                        _div(),
                        _toggle(
                          icon: Icons.calendar_today_outlined,
                          color: Colors.amber,
                          title: 'Daily Health Summary',
                          sub: 'Morning digest of health trends',
                          val: _dailySummaryEnabled,
                          enabled: true,
                          onChange: (v) {
                            setState(() => _dailySummaryEnabled = v);
                            _savePref('daily_summary', v);
                          },
                        ),
                      ]),

                      const SizedBox(height: 20),
                      _label('Support & Help', Icons.help_outline),
                      const SizedBox(height: 10),
                      _card([
                        _tap(
                            icon: Icons.quiz_outlined,
                            color: Colors.tealAccent,
                            title: 'FAQ & Help Center',
                            sub: 'Answers to common questions',
                            onTap: _showFaqSheet),
                        _div(),
                        _tap(
                            icon: Icons.support_agent_outlined,
                            color: Colors.cyanAccent,
                            title: 'Contact Support',
                            sub: 'teamnexora2026@gmail.com',
                            onTap: _launchSupportEmail),
                        _div(),
                        _tap(
                            icon: Icons.star_outline_rounded,
                            color: Colors.amber,
                            title: 'Rate the App',
                            sub: 'Tell us what you think',
                            onTap: _showRatingDialog),
                        _div(),
                        _tap(
                            icon: Icons.bug_report_outlined,
                            color: Colors.orangeAccent,
                            title: 'Report a Bug',
                            sub: 'Help us improve MediTwin',
                            onTap: _launchBugReportForm),
                      ]),

                      const SizedBox(height: 20),
                      _label('Legal', Icons.gavel_rounded),
                      const SizedBox(height: 10),
                      _card([
                        _tap(
                          icon: Icons.gavel_rounded,
                          color: Colors.blueAccent,
                          title: 'Terms of Service',
                          sub: 'Effective Jan 1, 2026 · v3.1.0',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LegalDocumentScreen(
                                      type: LegalDocType.terms))),
                        ),
                        _div(),
                        _tap(
                          icon: Icons.shield_outlined,
                          color: Colors.greenAccent,
                          title: 'Privacy Policy',
                          sub: 'HIPAA & GDPR Compliant · v2.4.0',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LegalDocumentScreen(
                                      type: LegalDocType.privacy))),
                        ),
                        _div(),
                        _info(icon: Icons.verified_outlined,
                            title: 'Compliance',
                            val: 'HIPAA · GDPR'),
                        _div(),
                        _info(
                            icon: Icons.medical_services_outlined,
                            title: 'Device Class',
                            val: 'Class II – Wellness'),
                      ]),

                      const SizedBox(height: 20),
                      _label('About', Icons.info_outline),
                      const SizedBox(height: 10),
                      _card([
                        _tap(
                            icon: Icons.info_outline,
                            color: Colors.white54,
                            title: 'About NEXORA MediTwin',
                            sub: 'Version 1.0.0 (Build 42)',
                            onTap: _showAboutDialog),
                        _div(),
                        _info(
                            icon: Icons.memory_outlined,
                            title: 'Bio-Patch Protocol',
                            val: 'ESP-32 v2.1'),
                        _div(),
                        _info(
                            icon: Icons.security_outlined,
                            title: 'Encryption',
                            val: 'AES-256 · TLS 1.3'),
                      ]),

                      const SizedBox(height: 20),
                      _label('Danger Zone', Icons.warning_amber_rounded),
                      const SizedBox(height: 10),
                      _dangerCard(),

                      const SizedBox(height: 36),
                      const Center(
                        child: Column(children: [
                          Text('NEXORA MEDITWIN',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  fontSize: 12)),
                          SizedBox(height: 4),
                          Text(
                              '© 2025 NEXORA Technologies\nAll health data encrypted end-to-end.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 11,
                                  height: 1.7)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
    );
  }

  // ── WIDGETS ───────────────────────────────────────────────────────────────
  Widget _profileCard(String first, String last, String email,
      String patientId, String deviceId) {
    final paired = deviceId.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.primary.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(children: [
            Stack(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 14)
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$first $last',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(email,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, children: [
                      _chip(patientId, AppColors.primary),
                      _chip(
                          paired ? '● Paired' : '○ Unpaired',
                          paired ? Colors.greenAccent : Colors.white38),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(t,
          style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }

  Widget _dangerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showDeleteAccountDialog,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.delete_forever_outlined,
                        color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete My Account',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text(
                              'Permanently erase all data. Cannot be undone.',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic)),
                        ]),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.red, size: 20),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _label(String t, IconData icon) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 14),
      const SizedBox(width: 6),
      Text(t.toUpperCase(),
          style: const TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.6)),
    ]);
  }

  Widget _toggle({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required bool val,
    required bool enabled,
    required ValueChanged<bool> onChange,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(enabled ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(icon, color: enabled ? color : Colors.white24, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: enabled ? Colors.white : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(sub,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11.5)),
              ]),
        ),
        Switch.adaptive(
            value: val,
            onChanged: enabled ? onChange : null,
            activeColor: AppColors.primary),
      ]),
    );
  }

  Widget _tap({
    required IconData icon,
    required Color color,
    required String title,
    String? sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    if (sub != null)
                      Text(sub,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11.5)),
                  ]),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 19),
          ]),
        ),
      ),
    );
  }

  Widget _info(
      {required IconData icon, required String title, required String val}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, color: Colors.white38, size: 19),
        const SizedBox(width: 12),
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14))),
        Text(val,
            style: const TextStyle(
                color: Colors.white38, fontSize: 12, letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _div() =>
      Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 16);

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 16),
          onPressed: onTap,
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints()),
    );
  }
}

// ── FAQ TILE ──────────────────────────────────────────────────────────────────
class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: _open
            ? AppColors.primary.withOpacity(0.07)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _open
                ? AppColors.primary.withOpacity(0.3)
                : Colors.white.withOpacity(0.07)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5))),
                Icon(
                    _open
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20),
              ]),
              if (_open) ...[
                const SizedBox(height: 8),
                Text(widget.answer,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.55)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ── GRID PAINTER ─────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}