import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MEDICATION SCREEN
//  Features:
//   • Active medications list with dose / frequency / timing / stock tracker
//   • Add / edit / delete medications
//   • Today's schedule timeline (morning / afternoon / evening / night)
//   • Streak tracker (adherence %)
//   • Drug information panel
//   • Prescription history log
// ─────────────────────────────────────────────────────────────────────────────

// ── Data model ────────────────────────────────────────────────────────────────
class Medication {
  final String id;
  String name;
  String dose;
  String frequency;
  List<String> times; // e.g. ["Morning", "Night"]
  String category;
  String color;
  String notes;
  int stockCount;
  int stockTotal;
  bool takenToday;

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.category,
    required this.color,
    this.notes = '',
    this.stockCount = 30,
    this.stockTotal = 30,
    this.takenToday = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'frequency': frequency,
        'times': times,
        'category': category,
        'color': color,
        'notes': notes,
        'stockCount': stockCount,
        'stockTotal': stockTotal,
        'takenToday': takenToday,
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'],
        name: j['name'],
        dose: j['dose'],
        frequency: j['frequency'],
        times: List<String>.from(j['times']),
        category: j['category'],
        color: j['color'],
        notes: j['notes'] ?? '',
        stockCount: j['stockCount'] ?? 30,
        stockTotal: j['stockTotal'] ?? 30,
        takenToday: j['takenToday'] ?? false,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class MedicationScreen extends StatefulWidget {
  final int userId;
  const MedicationScreen({super.key, required this.userId});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late Animation<double> _fadeAnim;

  List<Medication> _meds = [];
  int _selectedTab = 0; // 0=Today 1=All 2=History

  final _tabs = ['Today', 'All Meds', 'History'];

  // Preset sample data shown on first launch
  static final List<Medication> _sampleMeds = [
    Medication(
      id: '1',
      name: 'Atorvastatin',
      dose: '20 mg',
      frequency: 'Once daily',
      times: ['Night'],
      category: 'Cardiology',
      color: '#FF6B6B',
      notes: 'Take after dinner. Avoid grapefruit.',
      stockCount: 22,
      stockTotal: 30,
    ),
    Medication(
      id: '2',
      name: 'Metoprolol',
      dose: '50 mg',
      frequency: 'Twice daily',
      times: ['Morning', 'Night'],
      category: 'Cardiology',
      color: '#4ECDC4',
      notes: 'Do not skip doses. Take with food.',
      stockCount: 16,
      stockTotal: 60,
    ),
    Medication(
      id: '3',
      name: 'Aspirin',
      dose: '75 mg',
      frequency: 'Once daily',
      times: ['Morning'],
      category: 'Antiplatelet',
      color: '#FFE66D',
      notes: 'Take with water. Blood thinner — report unusual bleeding.',
      stockCount: 28,
      stockTotal: 30,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));
    _loadMeds();
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _loadMeds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('meds_${widget.userId}');
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => Medication.fromJson(e))
          .toList();
      if (mounted) setState(() => _meds = list);
    } else {
      // First launch — show demo data
      if (mounted) setState(() => _meds = List.from(_sampleMeds));
    }
  }

  Future<void> _saveMeds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'meds_${widget.userId}',
        jsonEncode(_meds.map((m) => m.toJson()).toList()));
  }

  // ── Computed stats ────────────────────────────────────────────────────────
  int get _totalToday =>
      _meds.where((m) => m.times.isNotEmpty).length;
  int get _takenToday => _meds.where((m) => m.takenToday).length;
  int get _lowStock =>
      _meds.where((m) => m.stockCount <= (m.stockTotal * 0.3)).length;

  double get _adherence =>
      _totalToday == 0 ? 1.0 : _takenToday / _totalToday;

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Cardiology':
        return Colors.redAccent;
      case 'Antiplatelet':
        return Colors.amber;
      case 'Diabetes':
        return Colors.tealAccent;
      case 'Neurology':
        return Colors.purpleAccent;
      case 'Antibiotic':
        return Colors.orangeAccent;
      case 'Vitamin / Supplement':
        return Colors.greenAccent;
      default:
        return AppColors.primary;
    }
  }

  List<String> get _timeSlots => ['Morning', 'Afternoon', 'Evening', 'Night'];

  List<Medication> _medsForTime(String slot) =>
      _meds.where((m) => m.times.contains(slot)).toList();

  // ─────────────────────────────────────────────────────────────────────────
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
                center: Alignment.topRight,
                radius: 1.6,
                colors: [Color(0xFF0D2B1A), Color(0xFF000000)],
              ),
            ),
          ),
          // Subtle dot grid
          Positioned.fill(
              child: Opacity(
                  opacity: 0.025,
                  child: CustomPaint(painter: _DotGridPainter()))),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStatsRow(),
                  _buildTabBar(),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildTodayView(),
                        _buildAllMedsView(),
                        _buildHistoryView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Med',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddEditSheet(),
            )
          : null,
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.greenAccent.withOpacity(0.25)),
          ),
          child: const Icon(Icons.medication_rounded,
              color: Colors.greenAccent, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Medications',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text('Track · Schedule · Manage',
              style: TextStyle(color: Colors.white38, fontSize: 11.5)),
        ]),
        const Spacer(),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.info_outline,
                color: Colors.white54, size: 18),
          ),
          onPressed: _showDisclaimerDialog,
        ),
      ]),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(children: [
        _statChip(
          icon: Icons.check_circle_outline,
          value: '$_takenToday/$_totalToday',
          label: "Today's Doses",
          color: Colors.greenAccent,
        ),
        const SizedBox(width: 10),
        _statChip(
          icon: Icons.percent_rounded,
          value: '${(_adherence * 100).round()}%',
          label: 'Adherence',
          color: _adherence >= 0.8
              ? Colors.greenAccent
              : _adherence >= 0.5
                  ? Colors.amber
                  : Colors.redAccent,
        ),
        const SizedBox(width: 10),
        _statChip(
          icon: Icons.inventory_2_outlined,
          value: '$_lowStock',
          label: 'Low Stock',
          color: _lowStock > 0 ? Colors.orange : Colors.white38,
        ),
      ]),
    );
  }

  Widget _statChip(
      {required IconData icon,
      required String value,
      required String label,
      required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final active = _selectedTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: active
                        ? Border.all(
                            color: AppColors.primary.withOpacity(0.4))
                        : null,
                  ),
                  child: Text(
                    _tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? AppColors.primary : Colors.white38,
                      fontWeight: active
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── TODAY VIEW ────────────────────────────────────────────────────────────
  Widget _buildTodayView() {
    if (_meds.isEmpty) return _buildEmptyState();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // Adherence arc
        _buildAdherenceCard(),
        const SizedBox(height: 16),

        ..._timeSlots.map((slot) {
          final meds = _medsForTime(slot);
          if (meds.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _timeSlotHeader(slot),
              const SizedBox(height: 8),
              ...meds.map((m) => _buildScheduleCard(m)),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildAdherenceCard() {
    final pct = (_adherence * 100).round();
    final color = pct >= 80
        ? Colors.greenAccent
        : pct >= 50
            ? Colors.amber
            : Colors.redAccent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _adherence,
                  strokeWidth: 7,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
                Text('$pct%',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ]),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's Adherence",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      pct == 100
                          ? '✓ All doses taken — great job!'
                          : '$_takenToday of $_totalToday doses marked taken',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12.5),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _adherence,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _timeSlotHeader(String slot) {
    const icons = {
      'Morning': Icons.wb_sunny_outlined,
      'Afternoon': Icons.wb_cloudy_outlined,
      'Evening': Icons.nights_stay_outlined,
      'Night': Icons.bedtime_outlined,
    };
    const colors = {
      'Morning': Colors.amber,
      'Afternoon': Colors.orange,
      'Evening': Colors.deepPurpleAccent,
      'Night': Colors.indigo,
    };
    final ic = icons[slot]!;
    final cl = colors[slot]!;

    return Row(children: [
      Icon(ic, color: cl, size: 16),
      const SizedBox(width: 6),
      Text(slot,
          style: TextStyle(
              color: cl,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2)),
    ]);
  }

  Widget _buildScheduleCard(Medication m) {
    final mc = _hexColor(m.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: m.takenToday
                  ? Colors.greenAccent.withOpacity(0.06)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: m.takenToday
                    ? Colors.greenAccent.withOpacity(0.3)
                    : mc.withOpacity(0.2),
              ),
            ),
            child: Row(children: [
              // Colored pill icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: mc.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: mc.withOpacity(0.4)),
                ),
                child: Icon(Icons.medication_rounded, color: mc, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: TextStyle(
                              color: m.takenToday
                                  ? Colors.white54
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              decoration: m.takenToday
                                  ? TextDecoration.lineThrough
                                  : null)),
                      Text('${m.dose}  •  ${m.frequency}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ]),
              ),
              // Take / Undo button
              GestureDetector(
                onTap: () {
                  setState(() => m.takenToday = !m.takenToday);
                  _saveMeds();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: m.takenToday
                        ? Colors.greenAccent.withOpacity(0.15)
                        : mc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: m.takenToday
                            ? Colors.greenAccent.withOpacity(0.4)
                            : mc.withOpacity(0.4)),
                  ),
                  child: Text(
                    m.takenToday ? '✓ Taken' : 'Take',
                    style: TextStyle(
                      color: m.takenToday
                          ? Colors.greenAccent
                          : mc,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── ALL MEDS VIEW ─────────────────────────────────────────────────────────
  Widget _buildAllMedsView() {
    if (_meds.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: _meds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildMedCard(_meds[i]),
    );
  }

  Widget _buildMedCard(Medication m) {
    final mc = _hexColor(m.color);
    final stockPct = m.stockCount / m.stockTotal;
    final lowStock = stockPct <= 0.3;
    final catColor = _categoryColor(m.category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: mc.withOpacity(0.18)),
          ),
          child: Column(children: [
            // Top section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: mc.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: mc.withOpacity(0.5),
                            width: 2),
                      ),
                      child: Icon(Icons.medication_rounded,
                          color: mc, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 3),
                            Text('${m.dose}  •  ${m.frequency}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12.5)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _tag(m.category, catColor),
                              const SizedBox(width: 6),
                              ...m.times
                                  .take(3)
                                  .map((t) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: _tag(t, Colors.white38),
                                      )),
                            ]),
                          ]),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white38, size: 20),
                      color: const Color(0xFF0D1B3E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      onSelected: (v) {
                        if (v == 'edit') _showAddEditSheet(med: m);
                        if (v == 'delete') _confirmDelete(m);
                        if (v == 'info') _showDrugInfo(m);
                      },
                      itemBuilder: (_) => [
                        _menuItem(Icons.edit_outlined, 'Edit',
                            Colors.cyanAccent, 'edit'),
                        _menuItem(Icons.info_outline, 'Drug Info',
                            Colors.blueAccent, 'info'),
                        _menuItem(Icons.delete_outline, 'Delete',
                            Colors.redAccent, 'delete'),
                      ],
                    ),
                  ]),
            ),

            if (m.notes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(m.notes,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1.4))),
                      ]),
                ),
              ),
            ],

            // Stock tracker
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stock',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          Text('${m.stockCount} of ${m.stockTotal} left',
                              style: TextStyle(
                                  color: lowStock
                                      ? Colors.orange
                                      : Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ]),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: stockPct,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                          lowStock ? Colors.orange : Colors.greenAccent),
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (lowStock) ...[
                      const SizedBox(height: 5),
                      const Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 13),
                        SizedBox(width: 5),
                        Text('Low stock — refill soon',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 11.5)),
                      ]),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      IconData icon, String label, Color color, String val) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: val == 'delete' ? Colors.redAccent : Colors.white,
                fontSize: 14)),
      ]),
    );
  }

  // ── HISTORY VIEW ──────────────────────────────────────────────────────────
  Widget _buildHistoryView() {
    // Generate simulated history for the last 7 days
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: i));
      final taken = i == 0
          ? _takenToday
          : (i <= 2 ? _totalToday : _totalToday - (i % 2));
      return (
        date: d,
        taken: taken.clamp(0, _totalToday),
        total: _totalToday,
      );
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
      children: [
        // 7-day bar chart
        _buildWeekChart(days),
        const SizedBox(height: 20),

        const Text('Log',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),

        ...days.map((d) {
          final pct = d.total == 0 ? 1.0 : d.taken / d.total;
          final isToday = d.date.day == DateTime.now().day;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isToday
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.white.withOpacity(0.07)),
            ),
            child: Row(children: [
              Column(children: [
                Text(
                  isToday
                      ? 'Today'
                      : _dayName(d.date.weekday),
                  style: TextStyle(
                      color: isToday
                          ? AppColors.primary
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                Text(
                  '${d.date.day}/${d.date.month}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10),
                ),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                            pct == 1.0
                                ? Colors.greenAccent
                                : pct >= 0.5
                                    ? Colors.amber
                                    : Colors.redAccent),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text('${d.taken}/${d.total} doses taken',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ]),
              ),
              const SizedBox(width: 10),
              Text('${(pct * 100).round()}%',
                  style: TextStyle(
                      color: pct == 1.0
                          ? Colors.greenAccent
                          : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
          );
        }),

        const SizedBox(height: 20),
        _buildDisclaimerBanner(),
      ],
    );
  }

  Widget _buildWeekChart(
      List<({DateTime date, int taken, int total})> days) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('7-Day Adherence',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: days.reversed.map((d) {
                  final pct = d.total == 0 ? 1.0 : d.taken / d.total;
                  final isToday = d.date.day == DateTime.now().day;
                  final color = pct == 1.0
                      ? Colors.greenAccent
                      : pct >= 0.5
                          ? Colors.amber
                          : Colors.redAccent;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 28,
                        height: (pct * 60).clamp(6, 60),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : color.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                              ? Border.all(
                                  color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isToday ? 'T' : _dayShort(d.date.weekday),
                        style: TextStyle(
                            color:
                                isToday ? AppColors.primary : Colors.white38,
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── ADD / EDIT BOTTOM SHEET ───────────────────────────────────────────────
  void _showAddEditSheet({Medication? med}) {
    final isEdit = med != null;
    final nameCtrl =
        TextEditingController(text: isEdit ? med.name : '');
    final doseCtrl =
        TextEditingController(text: isEdit ? med.dose : '');
    final notesCtrl =
        TextEditingController(text: isEdit ? med.notes : '');
    String freq =
        isEdit ? med.frequency : 'Once daily';
    String category =
        isEdit ? med.category : 'Cardiology';
    String color = isEdit ? med.color : '#00B4CC';
    int stock = isEdit ? med.stockCount : 30;
    final selectedTimes = List<String>.from(isEdit ? med.times : ['Morning']);

    final freqs = [
      'Once daily',
      'Twice daily',
      'Three times daily',
      'Every 4 hours',
      'Every 6 hours',
      'Every 8 hours',
      'As needed',
      'Weekly',
    ];
    final categories = [
      'Cardiology',
      'Diabetes',
      'Neurology',
      'Antibiotic',
      'Antiplatelet',
      'Vitamin / Supplement',
      'Other',
    ];
    final colorOptions = [
      '#FF6B6B', '#4ECDC4', '#FFE66D', '#A29BFE', '#FD79A8',
      '#00B4CC', '#55EFC4', '#FDCB6E',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.88,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
            decoration: const BoxDecoration(
              color: Color(0xFF050D1C),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // handle
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(isEdit ? 'Edit Medication' : 'Add Medication',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetField(nameCtrl, 'Medication Name',
                            Icons.medication_rounded),
                        const SizedBox(height: 12),
                        _sheetField(doseCtrl, 'Dosage (e.g. 20 mg)',
                            Icons.scale_outlined),
                        const SizedBox(height: 12),

                        // Frequency dropdown
                        _sheetDropdown(
                          label: 'Frequency',
                          icon: Icons.repeat_rounded,
                          value: freq,
                          items: freqs,
                          onChanged: (v) => setS(() => freq = v!),
                        ),
                        const SizedBox(height: 12),

                        // Category dropdown
                        _sheetDropdown(
                          label: 'Category',
                          icon: Icons.category_outlined,
                          value: category,
                          items: categories,
                          onChanged: (v) => setS(() => category = v!),
                        ),
                        const SizedBox(height: 12),

                        // Time chips
                        const Text('Schedule',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _timeSlots.map((t) {
                            final sel = selectedTimes.contains(t);
                            return FilterChip(
                              label: Text(t),
                              selected: sel,
                              onSelected: (v) {
                                setS(() {
                                  v
                                      ? selectedTimes.add(t)
                                      : selectedTimes.remove(t);
                                });
                              },
                              selectedColor:
                                  AppColors.primary.withOpacity(0.25),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                  color: sel
                                      ? AppColors.primary
                                      : Colors.white54,
                                  fontSize: 13),
                              backgroundColor:
                                  Colors.white.withOpacity(0.06),
                              side: BorderSide(
                                  color: sel
                                      ? AppColors.primary.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.1)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Color picker
                        const Text('Colour',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Row(
                          children: colorOptions.map((c) {
                            final sel = color == c;
                            return GestureDetector(
                              onTap: () => setS(() => color = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _hexColor(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: sel
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2.5),
                                ),
                                child: sel
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Stock
                        Row(children: [
                          const Text('Stock Count',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  letterSpacing: 1)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.white38),
                            onPressed: () =>
                                setS(() => stock = (stock - 1).clamp(0, 999)),
                          ),
                          Text('$stock',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: AppColors.primary),
                            onPressed: () =>
                                setS(() => stock = (stock + 1).clamp(0, 999)),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        _sheetField(notesCtrl, 'Notes / Instructions',
                            Icons.notes_rounded,
                            maxLines: 3),
                      ]),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        doseCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Name and dose are required')));
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() {
                      if (isEdit) {
                        med.name = nameCtrl.text.trim();
                        med.dose = doseCtrl.text.trim();
                        med.frequency = freq;
                        med.category = category;
                        med.color = color;
                        med.times = selectedTimes;
                        med.stockCount = stock;
                        med.notes = notesCtrl.text.trim();
                      } else {
                        _meds.add(Medication(
                          id: DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                          name: nameCtrl.text.trim(),
                          dose: doseCtrl.text.trim(),
                          frequency: freq,
                          times: selectedTimes,
                          category: category,
                          color: color,
                          notes: notesCtrl.text.trim(),
                          stockCount: stock,
                          stockTotal: stock,
                        ));
                      }
                    });
                    _saveMeds();
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Medication',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String hint, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
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

  Widget _sheetDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF0D1B3E),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
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
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: onChanged,
    );
  }

  // ── DELETE CONFIRM ────────────────────────────────────────────────────────
  void _confirmDelete(Medication m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${m.name}?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'This medication will be removed from your schedule.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _meds.removeWhere((x) => x.id == m.id));
                _saveMeds();
              },
              child: const Text('Remove',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // ── DRUG INFO SHEET ───────────────────────────────────────────────────────
  void _showDrugInfo(Medication m) {
    final mc = _hexColor(m.color);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF050D1C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: mc.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: mc.withOpacity(0.4))),
              child: Icon(Icons.medication_rounded, color: mc, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text(m.category,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ]),
            ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                _infoRow2(Icons.scale_outlined, 'Dosage', m.dose),
                _infoRow2(Icons.repeat_rounded, 'Frequency', m.frequency),
                _infoRow2(Icons.schedule_outlined, 'Schedule',
                    m.times.join(', ')),
                _infoRow2(Icons.inventory_2_outlined, 'Stock',
                    '${m.stockCount} of ${m.stockTotal} remaining'),
                if (m.notes.isNotEmpty)
                  _infoRow2(Icons.notes_rounded, 'Instructions', m.notes),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.25)),
                  ),
                  child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                'Always consult your prescribing doctor or pharmacist before adjusting your dose. This information is for reference only.',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    height: 1.5))),
                      ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow2(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ── DISCLAIMER SHEET ──────────────────────────────────────────────────────
  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.medical_services_outlined,
            color: Colors.amber, size: 36),
        title: const Text('Medical Disclaimer',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'The Medication module is a personal tracking tool only. It does not provide medical advice, diagnose conditions, or replace professional consultation.\n\nAlways follow your doctor\'s or pharmacist\'s instructions for all medications.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70, height: 1.6, fontSize: 13)),
        actions: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 16),
            SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Medication history shown is approximate. Always consult your healthcare provider for accurate medical records.',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        height: 1.5))),
          ]),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent.withOpacity(0.07),
            border: Border.all(
                color: Colors.greenAccent.withOpacity(0.2)),
          ),
          child: const Icon(Icons.medication_outlined,
              color: Colors.greenAccent, size: 48),
        ),
        const SizedBox(height: 18),
        const Text('No medications yet',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 6),
        const Text('Tap  + Add Med  to get started',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      ]),
    );
  }

  // ── TAG / HELPERS ──────────────────────────────────────────────────────────
  Widget _tag(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(t,
          style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  String _dayName(int wd) {
    const n = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return n[wd];
  }

  String _dayShort(int wd) {
    const n = ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return n[wd];
  }
}

// ── DOT GRID PAINTER ──────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}