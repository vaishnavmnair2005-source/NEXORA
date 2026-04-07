import 'package:flutter/material.dart';
import '../utils/constants.dart'; // Make sure this points to your AppColors file

class ECGWave extends StatefulWidget {
  final Color color;
  const ECGWave({super.key, this.color = Colors.cyanAccent});

  @override
  State<ECGWave> createState() => _ECGWaveState();
}

class _ECGWaveState extends State<ECGWave> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Speed of the wave
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        size: const Size(double.infinity, 50),
        painter: _ECGPainter(_controller, widget.color),
      ),
    );
  }
}

class _ECGPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _ECGPainter(this.animation, this.color) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final double centerY = size.height / 2;
    final double width = size.width;

    // Shift the starting point based on animation value
    double shift = animation.value * width;

    for (double x = 0; x < width; x++) {
      double position = (x + shift) % width;
      double t = position / width;
      double y = centerY;

      // Draw the P-Q-R-S-T wave pattern
      if (t > 0.10 && t < 0.15) y -= 4;        // P wave
      else if (t > 0.18 && t < 0.20) y += 4;   // Q wave
      else if (t > 0.20 && t < 0.26) y -= 20;  // R wave (Spike)
      else if (t > 0.26 && t < 0.28) y += 8;   // S wave
      else if (t > 0.35 && t < 0.45) y -= 6;   // T wave
      
      if (x == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ECGPainter oldDelegate) => true;
}