import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../utils/constants.dart';

class HealthTrendsScreen extends StatefulWidget {
  final int userId;
  const HealthTrendsScreen({super.key, required this.userId});

  @override
  State<HealthTrendsScreen> createState() => _HealthTrendsScreenState();
}

class _HealthTrendsScreenState extends State<HealthTrendsScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;
  int _selectedTab = 0;

  // --- SIMULATED 7-DAY HISTORY DATA ---
  // In production, replace with API call: GET /app/vitals-history/{userId}
  final Map<String, List<FlSpot>> _historyData = {};
  final Map<String, List<String>> _timeLabels = {};

  final List<_TrendConfig> _trends = [
    _TrendConfig("Heart Rate", "BPM", Icons.favorite_rounded,
        const Color(0xFFFF4F6B), 55, 100),
    _TrendConfig("SpO₂", "%", Icons.water_drop_rounded,
        const Color(0xFF4FC3F7), 94, 100),
    _TrendConfig("Temperature", "°C", Icons.thermostat_rounded,
        const Color(0xFFFFB347), 36.0, 37.5),
    _TrendConfig("HRV", "ms", Icons.graphic_eq_rounded,
        const Color(0xFFB39DDB), 40, 80),
  ];

  @override
  void initState() {
    super.initState();

    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));

    _generateSimulatedHistory();
  }

  void _generateSimulatedHistory() {
    final rand = math.Random(42);
    final now = DateTime.now();

    // Generate 24 data points (last 7 days, ~3 per day)
    final baselines = [72.0, 98.0, 36.6, 58.0];
    final variances = [8.0, 2.0, 0.4, 10.0];
    final keys = ["Heart Rate", "SpO₂", "Temperature", "HRV"];

    for (int k = 0; k < keys.length; k++) {
      List<FlSpot> spots = [];
      List<String> labels = [];
      for (int i = 0; i < 24; i++) {
        double val =
            baselines[k] + (rand.nextDouble() - 0.5) * variances[k] * 2;
        spots.add(FlSpot(i.toDouble(), double.parse(val.toStringAsFixed(1))));
        final dt = now.subtract(Duration(hours: (23 - i) * 7));
        labels.add(i % 4 == 0
            ? "${dt.day}/${dt.month}"
            : "");
      }
      _historyData[keys[k]] = spots;
      _timeLabels[keys[k]] = labels;
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildTabRow(),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    child: Column(
                      children: [
                        _buildMainChart(),
                        const SizedBox(height: 20),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildAllVitalsMiniCharts(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
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
                child: const Text(
                  "Health Trends",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: AppColors.primary, size: 12),
                const SizedBox(width: 6),
                const Text("Last 7 Days",
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB ROW ───────────────────────────────────────────────────
  Widget _buildTabRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _trends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = _selectedTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          _trends[i].color.withOpacity(0.3),
                          _trends[i].color.withOpacity(0.1)
                        ],
                      )
                    : null,
                color: selected ? null : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? _trends[i].color.withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(_trends[i].icon,
                      color: selected
                          ? _trends[i].color
                          : Colors.white38,
                      size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _trends[i].label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── MAIN CHART ────────────────────────────────────────────────
  Widget _buildMainChart() {
    final trend = _trends[_selectedTab];
    final spots = _historyData[trend.label] ?? [];
    final labels = _timeLabels[trend.label] ?? [];

    // Calculate min/max for Y axis
    final vals = spots.map((s) => s.y).toList();
    final minY =
        (vals.isEmpty ? trend.minY : vals.reduce(math.min)) - 2;
    final maxY =
        (vals.isEmpty ? trend.maxY : vals.reduce(math.max)) + 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: trend.color.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                  color: trend.color.withOpacity(0.06),
                  blurRadius: 30,
                  spreadRadius: 2)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chart title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: trend.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(trend.icon, color: trend.color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trend.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text("7-day trend",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  // Current value badge
                  if (spots.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: trend.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: trend.color.withOpacity(0.3)),
                      ),
                      child: Text(
                        "${spots.last.y} ${trend.unit}",
                        style: TextStyle(
                            color: trend.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.white.withOpacity(0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (val, _) => Text(
                            val.toStringAsFixed(
                                trend.label == "Temperature" ? 1 : 0),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (val, _) {
                            final i = val.toInt();
                            if (i < labels.length &&
                                labels[i].isNotEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(top: 6),
                                child: Text(labels[i],
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor:
                            const Color(0xFF0A0A1A).withOpacity(0.95),
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem(
                                  "${s.y} ${trend.unit}",
                                  TextStyle(
                                      color: trend.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ))
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: trend.color,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                            radius: 3,
                            color: trend.color,
                            strokeWidth: 1.5,
                            strokeColor: Colors.black,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              trend.color.withOpacity(0.18),
                              trend.color.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STATS ROW ────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final trend = _trends[_selectedTab];
    final spots = _historyData[trend.label] ?? [];
    if (spots.isEmpty) return const SizedBox.shrink();

    final vals = spots.map((s) => s.y).toList();
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    final min = vals.reduce(math.min);
    final max = vals.reduce(math.max);

    return Row(
      children: [
        Expanded(
            child: _buildStatCard("Average",
                avg.toStringAsFixed(1), trend.unit, trend.color, Icons.bar_chart)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard("Minimum",
                min.toStringAsFixed(1), trend.unit, const Color(0xFF4FC3F7), Icons.arrow_downward)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard("Maximum",
                max.toStringAsFixed(1), trend.unit, const Color(0xFFFFB347), Icons.arrow_upward)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, String unit, Color color, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 5),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              Text(unit,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  // ── MINI CHARTS FOR ALL VITALS ────────────────────────────────
  Widget _buildAllVitalsMiniCharts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.grid_view_rounded,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          const Text("ALL VITALS OVERVIEW",
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _trends.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (_, i) => _buildMiniChart(_trends[i]),
        ),
      ],
    );
  }

  Widget _buildMiniChart(_TrendConfig trend) {
    final spots = _historyData[trend.label] ?? [];
    final isSelected = _trends[_selectedTab].label == trend.label;

    return GestureDetector(
      onTap: () => setState(
          () => _selectedTab = _trends.indexOf(trend)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                trend.color.withOpacity(isSelected ? 0.15 : 0.06),
                Colors.black.withOpacity(0.3)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: trend.color
                      .withOpacity(isSelected ? 0.5 : 0.2),
                  width: isSelected ? 1.5 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(trend.icon, color: trend.color, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(trend.label,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const Spacer(),
                  if (spots.isNotEmpty)
                    Text(
                      "${spots.last.y}",
                      style: TextStyle(
                          color: trend.color,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1),
                    ),
                  Text(trend.unit,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 35,
                    child: spots.isEmpty
                        ? const SizedBox.shrink()
                        : LineChart(
                            LineChartData(
                              gridData:
                                  const FlGridData(show: false),
                              borderData:
                                  FlBorderData(show: false),
                              titlesData: const FlTitlesData(
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                topTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                rightTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                              ),
                              lineTouchData: const LineTouchData(
                                  enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: trend.color,
                                  barWidth: 1.5,
                                  dotData: const FlDotData(
                                      show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: trend.color
                                        .withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(
                                milliseconds: 300),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── BACKGROUND (same as patient_dashboard) ────────────────────
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (_, __) => CustomPaint(
        painter:
            _TrendsBgPainter(_backgroundController.value),
        size: Size.infinite,
      ),
    );
  }
}

// ── DATA MODEL ────────────────────────────────────────────────
class _TrendConfig {
  final String label, unit;
  final IconData icon;
  final Color color;
  final double minY, maxY;
  _TrendConfig(this.label, this.unit, this.icon, this.color,
      this.minY, this.maxY);
}

// ── BACKGROUND PAINTER (same style as dashboard) ──────────────
class _TrendsBgPainter extends CustomPainter {
  final double t;
  _TrendsBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [Color(0xFF050D1F), Color(0xFF000000)],
              stops: [0.0, 0.9])
          .createShader(
              Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orb1 = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF00E5FF).withOpacity(0.07),
        Colors.transparent
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.85,
              size.height * 0.12 + 25 * math.sin(t * 2 * math.pi)),
          radius: 180));
    canvas.drawCircle(
        Offset(size.width * 0.85,
            size.height * 0.12 + 25 * math.sin(t * 2 * math.pi)),
        180,
        orb1);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendsBgPainter old) => true;
}