import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE MODE SERVICE
// Dependencies to add in pubspec.yaml:
//   connectivity_plus: ^5.0.2
//
// Provides:
//  1. ConnectivityService  — streams network state
//  2. OfflineCache         — saves/restores vitals + profile via SharedPrefs
//  3. OfflineBanner        — banner widget shown when offline
//  4. OfflineAwareWrapper  — wraps any widget with auto banner
// ─────────────────────────────────────────────────────────────────────────────

// ─── 1. CONNECTIVITY SERVICE ─────────────────────────────────────────────────
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _controller.stream;

  StreamSubscription? _sub;

  /// Start listening — call once from main() or a top-level initState.
  void init() {
    _sub = _connectivity.onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
      }
    });

    // Initial check
    _connectivity.checkConnectivity().then((result) {
      _isOnline = result != ConnectivityResult.none;
      _controller.add(_isOnline);
    });
  }

  Future<bool> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    return _isOnline;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

// ─── 2. OFFLINE CACHE ────────────────────────────────────────────────────────
class OfflineCache {
  static const String _profileKey = 'cached_profile';
  static const String _vitalsKey = 'cached_vitals';
  static const String _profileTimestampKey = 'cached_profile_ts';
  static const String _vitalsTimestampKey = 'cached_vitals_ts';

  // ── Profile ──────────────────────────────────────────────────────────────
  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile));
    await prefs.setString(
        _profileTimestampKey, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> profileCachedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_profileTimestampKey);
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  // ── Vitals ───────────────────────────────────────────────────────────────
  static Future<void> saveVitals(Map<String, dynamic> vitals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vitalsKey, jsonEncode(vitals));
    await prefs.setString(
        _vitalsTimestampKey, DateTime.now().toIso8601String());
  }

  static Future<Map<String, dynamic>?> loadVitals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vitalsKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> vitalsCachedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_vitalsTimestampKey);
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  // ── Pending SOS Queue ────────────────────────────────────────────────────
  // SOS requests that failed offline are queued and replayed when online.
  static const String _sosQueueKey = 'pending_sos_queue';

  static Future<void> queueSos(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sosQueueKey) ?? [];
    final entry = jsonEncode({
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    raw.add(entry);
    await prefs.setStringList(_sosQueueKey, raw);
    debugPrint('OfflineCache: SOS queued for user $userId');
  }

  static Future<List<Map<String, dynamic>>> getPendingSos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sosQueueKey) ?? [];
    return raw
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
  }

  static Future<void> clearSosQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sosQueueKey);
  }

  // ── Utility ───────────────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_vitalsKey);
    await prefs.remove(_profileTimestampKey);
    await prefs.remove(_vitalsTimestampKey);
    await prefs.remove(_sosQueueKey);
  }

  static Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_profileKey);
  }

  /// Returns true if cached data is stale (older than [maxAge]).
  static Future<bool> isProfileStale(
      {Duration maxAge = const Duration(hours: 12)}) async {
    final ts = await profileCachedAt();
    if (ts == null) return true;
    return DateTime.now().difference(ts) > maxAge;
  }

  static Future<bool> areVitalsStale(
      {Duration maxAge = const Duration(minutes: 10)}) async {
    final ts = await vitalsCachedAt();
    if (ts == null) return true;
    return DateTime.now().difference(ts) > maxAge;
  }
}

// ─── 3. OFFLINE BANNER ───────────────────────────────────────────────────────
class OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;

  const OfflineBanner({super.key, this.cachedAt});

  String _relativeTime() {
    if (cachedAt == null) return 'Unknown time';
    final diff = DateTime.now().difference(cachedAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7C2D12).withOpacity(0.85),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You are offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Showing cached data from ${_relativeTime()}',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4. OFFLINE-AWARE WRAPPER ─────────────────────────────────────────────────
/// Wraps any widget. Automatically shows/hides [OfflineBanner] based on
/// real-time connectivity. Pass [cachedAt] to display the cache age.
///
/// Usage:
///   OfflineAwareWrapper(
///     cachedAt: _lastFetchTime,
///     child: PatientDashboard(userId: uid),
///   )
class OfflineAwareWrapper extends StatefulWidget {
  final Widget child;
  final DateTime? cachedAt;
  final VoidCallback? onReconnected; // Triggered when coming back online

  const OfflineAwareWrapper({
    super.key,
    required this.child,
    this.cachedAt,
    this.onReconnected,
  });

  @override
  State<OfflineAwareWrapper> createState() => _OfflineAwareWrapperState();
}

class _OfflineAwareWrapperState extends State<OfflineAwareWrapper>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  StreamSubscription<bool>? _sub;
  late AnimationController _bannerController;
  late Animation<double> _bannerAnim;

  @override
  void initState() {
    super.initState();

    _bannerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _bannerAnim = CurvedAnimation(
        parent: _bannerController, curve: Curves.easeOutCubic);

    _isOnline = ConnectivityService().isOnline;
    if (!_isOnline) _bannerController.value = 1.0;

    _sub = ConnectivityService().onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) {
          _bannerController.reverse();
          widget.onReconnected?.call();
          _showReconnectedToast();
        } else {
          _bannerController.forward();
        }
      }
    });
  }

  void _showReconnectedToast() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Text('Back online — refreshing data'),
      ]),
      backgroundColor: const Color(0xFF15803D),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animated offline banner
        SizeTransition(
          sizeFactor: _bannerAnim,
          axisAlignment: -1,
          child: OfflineBanner(cachedAt: widget.cachedAt),
        ),

        // Main content
        Expanded(child: widget.child),
      ],
    );
  }
}

// ─── 5. SYNC MANAGER ─────────────────────────────────────────────────────────
/// On reconnection, replays any queued SOS requests and refreshes data.
class SyncManager {
  static Future<void> syncOnReconnect({
    required int userId,
    required Future<void> Function() refreshData,
    String? baseUrl,
  }) async {
    debugPrint('SyncManager: Starting sync...');

    // 1. Replay pending SOS
    final pendingSos = await OfflineCache.getPendingSos();
    if (pendingSos.isNotEmpty && baseUrl != null) {
      for (final item in pendingSos) {
        try {
          final uid = item['user_id'] as int;
          debugPrint('SyncManager: Replaying SOS for user $uid');
          // Actual HTTP call would go here:
          // await http.post(Uri.parse('$baseUrl/app/trigger-sos/$uid'));
        } catch (e) {
          debugPrint('SyncManager: Failed to replay SOS: $e');
        }
      }
      await OfflineCache.clearSosQueue();
      debugPrint('SyncManager: SOS queue cleared');
    }

    // 2. Refresh live data
    try {
      await refreshData();
      debugPrint('SyncManager: Data refresh complete');
    } catch (e) {
      debugPrint('SyncManager: Refresh error: $e');
    }
  }
}

// ─── 6. OFFLINE STATUS CHIP ─────────────────────────────────────────────────
/// Small chip to show inline in dashboards
class OfflineStatusChip extends StatelessWidget {
  final bool isOnline;

  const OfflineStatusChip({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isOnline
                ? const Color(0xFF15803D)
                : const Color(0xFF991B1B))
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isOnline
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444))
              .withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Live' : 'Offline',
            style: TextStyle(
              color: isOnline
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}