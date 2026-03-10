import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Drop-in shimmer skeleton that mirrors the PatientDashboard layout.
/// Usage: replace CircularProgressIndicator with DashboardShimmer()
class DashboardShimmer extends StatefulWidget {
  const DashboardShimmer({super.key});

  @override
  State<DashboardShimmer> createState() => _DashboardShimmerState();
}

class _DashboardShimmerState extends State<DashboardShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── SHIMMER PAINT ──────────────────────────────────────────
  Widget _shimmer(Widget child) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFF0D1B2E),
            Color(0xFF1A2F4A),
            Color(0xFF0A2240),
            Color(0xFF0D1B2E),
          ],
          stops: [
            0.0,
            (_anim.value + 2.0) / 4.0 - 0.1,
            (_anim.value + 2.0) / 4.0,
            1.0,
          ],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: child,
      ),
    );
  }

  // ── SHIMMER BOX ────────────────────────────────────────────
  Widget _box({
    double? width,
    double height = 16,
    double radius = 10,
  }) {
    return _shimmer(
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2F4A),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────
          Row(
            children: [
              _box(width: 200, height: 22, radius: 8),
              const Spacer(),
              _box(width: 36, height: 36, radius: 10),
            ],
          ),
          const SizedBox(height: 25),

          // ── Pair Button ─────────────────────────────────────
          _shimmer(
            Container(
              width: double.infinity,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Face Card ───────────────────────────────────────
          _shimmer(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  // Avatar circle
                  _shimmer(Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A2F4A),
                      shape: BoxShape.circle,
                    ),
                  )),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(width: 160, height: 18, radius: 6),
                        const SizedBox(height: 12),
                        _box(width: 120, height: 12, radius: 5),
                        const SizedBox(height: 8),
                        _box(width: 100, height: 12, radius: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Device status chip ───────────────────────────────
          _box(width: 220, height: 36, radius: 12),
          const SizedBox(height: 24),

          // ── Section label ────────────────────────────────────
          _box(width: 140, height: 12, radius: 5),
          const SizedBox(height: 10),

          // ── ECG card ─────────────────────────────────────────
          _shimmer(
            Container(
              width: double.infinity,
              height: 130,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Section label ────────────────────────────────────
          _box(width: 120, height: 12, radius: 5),
          const SizedBox(height: 10),

          // ── Vitals 2x3 grid ──────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (_, i) => _shimmer(
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _shimmer(Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: const Color(0xFF1A2F4A),
                              borderRadius:
                                  BorderRadius.circular(8)))),
                      const SizedBox(width: 8),
                      _box(width: 70, height: 10, radius: 4),
                    ]),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _box(
                              width: 55, height: 26, radius: 5),
                          const SizedBox(height: 4),
                          _box(
                              width: 30, height: 10, radius: 4),
                        ]),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── SOS button ───────────────────────────────────────
          _shimmer(
            Container(
              width: double.infinity,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}