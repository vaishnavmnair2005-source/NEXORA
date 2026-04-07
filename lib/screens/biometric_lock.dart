import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE LAYER: Wraps local_auth plugin
// ─────────────────────────────────────────────────────────────────────────────
class BiometricLockService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device has enrolled biometrics and hardware support.
  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Returns a list of available biometric types on the device.
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Triggers the OS-level authentication dialog.
  /// Returns true if authenticated successfully.
  static Future<bool> authenticate({String? reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason:
            reason ?? 'Authenticate to access Nexora MediTwin',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows PIN fallback
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: ${e.message}');
      return false;
    }
  }

  /// Checks SharedPreferences to see if the user has enabled biometric lock.
  static Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI GATE: Shown on app resume/launch when biometric lock is enabled.
// On success → pops and the underlying screen is revealed.
// ─────────────────────────────────────────────────────────────────────────────
class BiometricGateScreen extends StatefulWidget {
  final Widget child;
  final VoidCallback? onAuthenticated; // called by BiometricGatedPage for in-place unlock
  const BiometricGateScreen({super.key, required this.child, this.onAuthenticated});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen>
    with TickerProviderStateMixin {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _failed = false;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(_shakeController);

    // Auto-trigger on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _failed = false;
    });

    final success = await BiometricLockService.authenticate(
        reason: 'Unlock Nexora MediTwin to access your health data');

    if (mounted) {
      if (success) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          if (widget.onAuthenticated != null) {
            // Used inside BiometricGatedPage → unlock in-place, no navigation
            widget.onAuthenticated!();
          } else {
            // Used as a standalone route gate
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => widget.child,
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        }
      } else {
        setState(() {
          _failed = true;
          _isLoading = false;
        });
        _shakeController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF0A1628), Color(0xFF000000)],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // Glowing orb
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isAuthenticated
                            ? Colors.green
                            : _failed
                                ? Colors.red
                                : AppColors.primary)
                        .withOpacity(0.08),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          // Content
          Center(
            child: AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0),
                child: child,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Icon
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    ),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.03),
                        border: Border.all(
                          color: (_isAuthenticated
                                  ? Colors.green
                                  : _failed
                                      ? Colors.red
                                      : AppColors.primary)
                              .withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isAuthenticated
                                    ? Colors.green
                                    : _failed
                                        ? Colors.red
                                        : AppColors.primary)
                                .withOpacity(0.15),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isAuthenticated
                            ? Icons.check_rounded
                            : _failed
                                ? Icons.lock_outline
                                : Icons.fingerprint,
                        size: 56,
                        color: _isAuthenticated
                            ? Colors.green
                            : _failed
                                ? Colors.red
                                : AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Title
                  const Text(
                    'NEXORA MEDITWIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Status Message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isAuthenticated
                          ? 'Identity verified'
                          : _isLoading
                              ? 'Verifying identity...'
                              : _failed
                                  ? 'Authentication failed. Try again.'
                                  : 'Biometric authentication required',
                      key: ValueKey(_isAuthenticated
                          ? 'ok'
                          : _isLoading
                              ? 'loading'
                              : _failed
                                  ? 'fail'
                                  : 'idle'),
                      style: TextStyle(
                        color: _isAuthenticated
                            ? Colors.greenAccent
                            : _failed
                                ? Colors.redAccent
                                : Colors.white54,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Loading / Retry
                  if (_isLoading)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  else if (!_isAuthenticated)
                    GestureDetector(
                      onTap: _authenticate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.8),
                              AppColors.primary.withOpacity(0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 20),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _failed
                                  ? Icons.refresh
                                  : Icons.fingerprint,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _failed ? 'Try Again' : 'Authenticate',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WRAPPER: Wrap any page with biometric gate logic.
// • Checks SharedPrefs once on init
// • Re-locks automatically when the app comes back from background
// Usage:
//   BiometricGatedPage(child: MainScreen(userId: uid))
// ─────────────────────────────────────────────────────────────────────────────
class BiometricGatedPage extends StatefulWidget {
  final Widget child;
  const BiometricGatedPage({super.key, required this.child});

  @override
  State<BiometricGatedPage> createState() => _BiometricGatedPageState();
}

class _BiometricGatedPageState extends State<BiometricGatedPage>
    with WidgetsBindingObserver {
  bool _lockEnabled = false;
  bool _unlocked = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final enabled = await BiometricLockService.isLockEnabled();
    if (!mounted) return;
    setState(() {
      _lockEnabled = enabled;
      _unlocked = !enabled; // skip gate when disabled
      _checking = false;
    });
  }

  /// Re-lock when user returns from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _lockEnabled) {
      setState(() => _unlocked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAuthenticated() {
    if (mounted) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_lockEnabled && !_unlocked) {
      return BiometricGateScreen(
        onAuthenticated: _onAuthenticated,
        child: widget.child,
      );
    }
    return widget.child;
  }
}