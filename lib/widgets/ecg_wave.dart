import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

// ─────────────────────────────────────────────────────────────────────────────
//  ECGWave — Live AD8232 waveform over WebSocket
//
//  Usage:
//    ECGWave(ip: "10.151.185.143", color: Colors.greenAccent)
//
//  Pass ip = null or "" to show the "Enter IP" placeholder.
//  The widget reports connection state back via [onConnectionChanged].
// ─────────────────────────────────────────────────────────────────────────────

class ECGWave extends StatefulWidget {
  final String? ip;
  final Color color;

  /// Called whenever the connection state changes.
  /// true  → successfully receiving ECG data
  /// false → disconnected / error
  final ValueChanged<bool>? onConnectionChanged;

  const ECGWave({
    super.key,
    required this.ip,
    this.color = Colors.greenAccent,
    this.onConnectionChanged,
  });

  @override
  State<ECGWave> createState() => _ECGWaveState();
}

class _ECGWaveState extends State<ECGWave> {
  WebSocketChannel? _channel;
  final List<double> _buffer = List.filled(200, 0.0);
  int _writeIndex = 0;
  bool _leadsOk = true;
  bool _connected = false;
  bool _connectionFailed = false;        // true after first failed attempt
  bool _hadSuccessfulConnection = false; // true once we get real ECG data

  @override
  void initState() {
    super.initState();
    if (_hasIp) _connect();
  }

  @override
  void didUpdateWidget(covariant ECGWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the IP changed, drop old connection and reconnect
    if (oldWidget.ip != widget.ip) {
      _channel?.sink.close(ws_status.goingAway);
      _channel = null;
      setState(() {
        _connected = false;
        _connectionFailed = false;
        _hadSuccessfulConnection = false;
        _buffer.fillRange(0, _buffer.length, 0.0);
        _writeIndex = 0;
      });
      if (_hasIp) _connect();
    }
  }

  bool get _hasIp => widget.ip != null && widget.ip!.trim().isNotEmpty;

  void _connect() {
    if (!mounted || !_hasIp) return;
    try {
      _channel =
          WebSocketChannel.connect(Uri.parse('ws://${widget.ip!.trim()}:81'));

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message as String);
          if (data['type'] != 'ecg') return;

          final int raw = (data['value'] as num).toInt();
          final bool leads = data['leads_ok'] as bool;
          final double normalised = (raw - 2048.0) / 2048.0;

          if (!_connected || _connectionFailed) {
            widget.onConnectionChanged?.call(true);
          }

          setState(() {
            _connected = true;
            _connectionFailed = false;
            _hadSuccessfulConnection = true;
            _leadsOk = leads;
            _buffer[_writeIndex % _buffer.length] = normalised;
            _writeIndex++;
          });
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _connected = false;
              _connectionFailed = true;
            });
            widget.onConnectionChanged?.call(false);
            Future.delayed(const Duration(seconds: 3), _connect);
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _connected = false;
              _connectionFailed = true;
            });
            widget.onConnectionChanged?.call(false);
            Future.delayed(const Duration(seconds: 3), _connect);
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionFailed = true;
        });
        widget.onConnectionChanged?.call(false);
        Future.delayed(const Duration(seconds: 3), _connect);
      }
    }
  }

  @override
  void dispose() {
    _channel?.sink.close(ws_status.goingAway);
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No IP entered yet
    if (!_hasIp) {
      return _centeredMessage(
        icon: Icons.wifi_find,
        iconColor: Colors.white38,
        message: 'Enter ESP32 IP and press Connect',
        messageColor: Colors.white38,
      );
    }

    // Leads physically disconnected
    if (_connected && !_leadsOk) {
      return _centeredMessage(
        icon: Icons.sensors_off,
        iconColor: Colors.redAccent,
        message: 'Electrodes disconnected',
        messageColor: Colors.redAccent,
      );
    }

    // Connection failed (dropped after being live — not initial attempt)
    if (_connectionFailed && !_connected && _hadSuccessfulConnection) {
      return _centeredMessage(
        icon: Icons.wifi_off,
        iconColor: Colors.redAccent,
        message: 'Signal lost — reconnecting…',
        messageColor: Colors.redAccent,
      );
    }

    // Still trying to connect for the first time — show nothing (dashboard handles this UI)
    if (!_connected) {
      return const SizedBox(height: 50);
    }

    // ✅ Live ECG waveform
    return ClipRect(
      child: CustomPaint(
        size: const Size(double.infinity, 50),
        painter: _RealECGPainter(
          List<double>.from(_buffer),
          _writeIndex,
          widget.color,
        ),
      ),
    );
  }

  Widget _centeredMessage({
    required IconData? icon,
    required Color iconColor,
    required String message,
    required Color messageColor,
    bool showSpinner = false,
    Color spinnerColor = Colors.white,
  }) {
    return SizedBox(
      height: 50,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: spinnerColor),
              )
            else if (icon != null)
              Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 7),
            Text(message,
                style: TextStyle(color: messageColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter
// ─────────────────────────────────────────────────────────────────────────────

class _RealECGPainter extends CustomPainter {
  final List<double> buffer;
  final int writeIndex;
  final Color color;

  _RealECGPainter(this.buffer, this.writeIndex, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (buffer.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final n = buffer.length;
    final double centerY = size.height / 2;
    final double amplitude = size.height * 0.44;

    for (int i = 0; i < n; i++) {
      final int sampleIndex = (writeIndex + i) % n;
      final double x = (i / (n - 1)) * size.width;
      final double y = centerY - buffer[sampleIndex] * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RealECGPainter old) =>
      old.writeIndex != writeIndex;
}