import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfExportService {

  // ── Manual button click ───────────────────────────────────────────────────
  static Future<void> exportAndShare({
    required BuildContext context,
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> vitals,
  }) async {
    try {
      final bytes = await _buildPdf(userProfile: userProfile, vitals: vitals);
      final name = userProfile['first_name'] ?? 'Patient';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Nexora_Report_$name.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── 30-min automated silent save ──────────────────────────────────────────
  static Future<void> saveAutomatedReportLocally({
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> vitals,
  }) async {
    try {
      final bytes = await _buildPdf(userProfile: userProfile, vitals: vitals);
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/Nexora_AutoReport_$timestamp.pdf');
      await file.writeAsBytes(bytes);
      print('✅ Auto-report saved: ${file.path}');
    } catch (e) {
      print('❌ Auto-report save failed: $e');
    }
  }

  // ── Core builder ──────────────────────────────────────────────────────────
  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> vitals,
  }) async {
    final doc = pw.Document();

    // ── Colors ────────────────────────────────────────────────────────────
    const pageGrey    = PdfColor.fromInt(0xFFF4F6F9);
    const white       = PdfColors.white;
    const borderGrey  = PdfColor.fromInt(0xFFE2E8F0);
    const nexoraBlue  = PdfColor.fromInt(0xFF0D47A1);
    const textDark    = PdfColor.fromInt(0xFF1E293B);
    const textMid     = PdfColor.fromInt(0xFF475569);
    const textLight   = PdfColor.fromInt(0xFF94A3B8);
    const accentRed   = PdfColor.fromInt(0xFFE53935);
    const accentBlue  = PdfColor.fromInt(0xFF0288D1);
    const accentOrange= PdfColor.fromInt(0xFFFF6F00);
    const accentPurple= PdfColor.fromInt(0xFF7B1FA2);
    const accentGreen = PdfColor.fromInt(0xFF2E7D32);
    const amberBorder = PdfColor.fromInt(0xFFFBC02D);
    const amberBg     = PdfColor.fromInt(0xFFFFFDE7);
    const amberText   = PdfColor.fromInt(0xFFE65100);

    // ── Patient fields ────────────────────────────────────────────────────
    final fullName   = '${userProfile['first_name'] ?? ''} ${userProfile['last_name'] ?? ''}'.trim();
    final patientId  = userProfile['patient_id']     ?? 'N/A';
    final mrdNumber  = userProfile['mrd_number']     ?? 'N/A';
    final email      = userProfile['email']          ?? 'N/A';
    final dob        = userProfile['dob']            ?? 'N/A';
    final gender     = userProfile['gender']         ?? 'N/A';
    final phone      = userProfile['contact_number'] ?? 'N/A';
    final bloodGroup = userProfile['blood_group']    ?? 'N/A';
    final deviceId   = userProfile['device_id']      ?? 'Not paired';

    // ── Vitals fields ─────────────────────────────────────────────────────
    final bpm   = _fmt(vitals['bpm']);
    final spo2  = _fmt(vitals['spo2']);
    final temp  = _fmt(vitals['temp']);
    final rmssd = _fmt(vitals['hrv_rmssd']);
    final sdnn  = _fmt(vitals['hrv_sdnn']);
    final pnn50 = _fmt(vitals['hrv_pnn50']);
    final fall  = vitals['fall_status']?.toString() ?? 'Safe';

    // ── Auto-compute status badge ─────────────────────────────────────────
    final bpmV  = double.tryParse(bpm)  ?? 0;
    final spo2V = double.tryParse(spo2) ?? 0;
    final tempV = double.tryParse(temp) ?? 0;
    final bool isCritical = bpmV > 110 || bpmV < 45 || spo2V < 90 || tempV > 38.5 || fall != 'Safe';
    final bool isModerate = !isCritical && (bpmV > 100 || bpmV < 55 || spo2V < 95 || tempV > 37.5 || tempV < 36.0);
    final String statusLabel = isCritical ? 'STATUS: CRITICAL' : isModerate ? 'STATUS: REVIEW ADVISED' : 'STATUS: NORMAL';
    final PdfColor statusBg  = isCritical ? const PdfColor.fromInt(0xFFFFEBEE) : isModerate ? const PdfColor.fromInt(0xFFFFF8E1) : const PdfColor.fromInt(0xFFE8F5E9);
    final PdfColor statusFg  = isCritical ? const PdfColor.fromInt(0xFFC62828) : isModerate ? const PdfColor.fromInt(0xFFE65100) : const PdfColor.fromInt(0xFF2E7D32);

    // ── Date / time ───────────────────────────────────────────────────────
    final nowDate = DateFormat('dd MMM yyyy').format(DateTime.now());
    final nowTime = DateFormat('HH:mm').format(DateTime.now());

    // ── Shared header builder ─────────────────────────────────────────────
    pw.Widget buildHeader() => pw.Container(
      color: white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Logo + tagline
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            // Logo circle
            pw.Container(
              width: 40, height: 40,
              decoration: pw.BoxDecoration(
                color: nexoraBlue,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
              ),
              child: pw.Center(
                child: pw.Text('N',
                    style: pw.TextStyle(
                      color: white, fontSize: 20, fontWeight: pw.FontWeight.bold,
                    )),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('NEXORA MEDITWIN',
                  style: pw.TextStyle(
                    color: nexoraBlue, fontSize: 16,
                    fontWeight: pw.FontWeight.bold, letterSpacing: 1.2,
                  )),
              pw.SizedBox(height: 2),
              pw.Text('AI-Powered Remote Patient Monitoring',
                  style: pw.TextStyle(color: textLight, fontSize: 8)),
            ]),
          ]),

          // Right: Report type + status + date + ID
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('PATIENT HEALTH REPORT',
                style: pw.TextStyle(
                  color: textMid, fontSize: 9,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 0.8,
                )),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: statusBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(statusLabel,
                  style: pw.TextStyle(
                    color: statusFg, fontSize: 8,
                    fontWeight: pw.FontWeight.bold, letterSpacing: 0.5,
                  )),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $nowDate, $nowTime',
                style: pw.TextStyle(color: textLight, fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: nexoraBlue,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text('ID: $patientId',
                  style: pw.TextStyle(
                    color: white, fontSize: 8, fontWeight: pw.FontWeight.bold,
                  )),
            ),
          ]),
        ],
      ),
    );

    // ════════════════════════════════════════════════════════════════════
    // PAGE 1
    // ════════════════════════════════════════════════════════════════════
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        buildBackground: (_) => pw.Container(color: pageGrey),
      ),
      footer: (ctx) => pw.Container(
        color: white,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              // small logo dot
              pw.Container(
                width: 14, height: 14,
                decoration: pw.BoxDecoration(
                  color: nexoraBlue,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
                ),
                child: pw.Center(
                  child: pw.Text('N',
                      style: pw.TextStyle(color: white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text('Nexora MediTwin   Confidential',
                  style: pw.TextStyle(color: textLight, fontSize: 8)),
            ]),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(color: textLight, fontSize: 8)),
          ],
        ),
      ),
      build: (ctx) => [

        buildHeader(),

        pw.SizedBox(height: 20),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [

            // ── PATIENT INFORMATION ────────────────────────────────────
            _sectionLabel('Patient Information', nexoraBlue),
            pw.SizedBox(height: 10),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: borderGrey, width: 0.8),
              ),
              padding: const pw.EdgeInsets.all(18),
              child: pw.Column(children: [

                // Name row + MRD + blood group badge
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(fullName,
                        style: pw.TextStyle(
                          color: textDark, fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                      pw.Text('MRD: $mrdNumber',
                          style: pw.TextStyle(color: textMid, fontSize: 9)),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFE3F2FD),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(bloodGroup,
                            style: pw.TextStyle(
                              color: nexoraBlue, fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ),
                    ]),
                  ],
                ),

                pw.SizedBox(height: 12),
                pw.Divider(color: borderGrey, thickness: 0.6),
                pw.SizedBox(height: 10),

                // Info grid: 3 columns
                pw.Row(children: [
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _infoTile('Date of Birth', dob,    textLight, textDark),
                    pw.SizedBox(height: 10),
                    _infoTile('Gender',        gender, textLight, textDark),
                  ])),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _infoTile('Email Address',  email, textLight, textDark),
                    pw.SizedBox(height: 10),
                    _infoTile('Contact Number', phone, textLight, textDark),
                  ])),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _infoTile('Blood Group',         bloodGroup, textLight, textDark),
                    pw.SizedBox(height: 10),
                    _infoTile('Bio-Patch Device ID', deviceId,  textLight, textDark),
                  ])),
                ]),
              ]),
            ),

            pw.SizedBox(height: 22),

            // ── CURRENT VITALS SNAPSHOT ────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                _sectionLabel('Current Vitals Snapshot', nexoraBlue),
                pw.Text('— $nowDate',
                    style: pw.TextStyle(color: textLight, fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 10),

            // Row 1: Heart Rate | SpO2 | Body Temperature
            pw.Row(children: [
              _vitalCard(
                label: 'Heart Rate',
                value: bpm, unit: 'bpm',
                status: _vStatus(bpm, 60, 100),
                accent: accentRed,
                iconPainter: _heartIconPainter(accentRed),
                textDark: textDark, textLight: textLight,
                borderGrey: borderGrey,
              ),
              pw.SizedBox(width: 12),
              _vitalCard(
                label: 'SpO2 (Blood Oxygen)',
                value: spo2, unit: '%',
                status: _vStatus(spo2, 95, 100),
                accent: accentBlue,
                iconPainter: _circleIconPainter(accentBlue),
                textDark: textDark, textLight: textLight,
                borderGrey: borderGrey,
              ),
              pw.SizedBox(width: 12),
              _vitalCard(
                label: 'Body Temperature',
                value: temp, unit: '°C',
                status: _vStatus(temp, 36.0, 37.5),
                accent: accentOrange,
                iconPainter: _thermIconPainter(accentOrange),
                textDark: textDark, textLight: textLight,
                borderGrey: borderGrey,
              ),
            ]),

            pw.SizedBox(height: 12),

            // Row 2: HRV Analytics | Fall Detection
            pw.Row(children: [
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderGrey, width: 0.8),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                      // HRV wave icon — drawn as 3 horizontal bars
                      pw.CustomPaint(
                        size: const PdfPoint(14, 10),
                        painter: (canvas, size) {
                          canvas.setFillColor(accentPurple);
                          canvas.drawRect(0, 8, 14, 1.5);
                          canvas.fillPath();
                          canvas.drawRect(0, 4.5, 10, 1.5);
                          canvas.fillPath();
                          canvas.drawRect(0, 1, 7, 1.5);
                          canvas.fillPath();
                        },
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text('HRV Analytics',
                          style: pw.TextStyle(color: textLight, fontSize: 9)),
                    ]),
                    pw.SizedBox(height: 14),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _hrvCol('RMSSD', '$rmssd ms', accentPurple, textLight),
                        _hrvCol('SDNN',  '$sdnn ms',  accentPurple, textLight),
                        _hrvCol('pNN50', '$pnn50 %',  accentPurple, textLight),
                      ],
                    ),
                  ]),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: borderGrey, width: 0.8),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                      // Person/run icon — drawn as circle + triangle
                      pw.CustomPaint(
                        size: const PdfPoint(12, 14),
                        painter: (canvas, size) {
                          final color = fall == 'Safe' ? accentGreen : const PdfColor.fromInt(0xFFC62828);
                          canvas.setFillColor(color);
                          // head circle
                          canvas.drawEllipse(6, 12, 2.5, 2.5);
                          canvas.fillPath();
                          // body triangle (person running shape)
                          canvas.moveTo(6, 9);
                          canvas.lineTo(1, 2);
                          canvas.lineTo(11, 2);
                          canvas.closePath();
                          canvas.fillPath();
                        },
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text('Fall Detection Status',
                          style: pw.TextStyle(color: textLight, fontSize: 9)),
                    ]),
                    pw.SizedBox(height: 10),
                    pw.Text(fall,
                        style: pw.TextStyle(
                          color: fall == 'Safe' ? accentGreen : const PdfColor.fromInt(0xFFC62828),
                          fontSize: 20, fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 6),
                    _statusBadge(
                      fall == 'Safe' ? 'Normal' : 'Alert',
                      fall == 'Safe' ? const PdfColor.fromInt(0xFFE8F5E9) : const PdfColor.fromInt(0xFFFFEBEE),
                      fall == 'Safe' ? accentGreen : const PdfColor.fromInt(0xFFC62828),
                    ),
                  ]),
                ),
              ),
            ]),

            pw.SizedBox(height: 22),

            // ── MEDICAL DISCLAIMER ─────────────────────────────────────
            pw.Container(
              decoration: pw.BoxDecoration(
                color: amberBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: amberBorder, width: 0.8),
              ),
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  // Warning triangle — drawn with CustomPaint
                  pw.CustomPaint(
                    size: const PdfPoint(13, 12),
                    painter: (canvas, size) {
                      canvas.setFillColor(amberText);
                      canvas.moveTo(6.5, 11);
                      canvas.lineTo(0, 0);
                      canvas.lineTo(13, 0);
                      canvas.closePath();
                      canvas.fillPath();
                      // inner white exclamation body
                      canvas.setFillColor(white);
                      canvas.drawRect(5.7, 2.5, 1.5, 4.5);
                      canvas.fillPath();
                      canvas.drawEllipse(6.5, 1.2, 0.85, 0.85);
                      canvas.fillPath();
                    },
                  ),
                  pw.SizedBox(width: 7),
                  pw.Text('Medical Disclaimer',
                      style: pw.TextStyle(
                        color: amberText, fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      )),
                ]),
                pw.SizedBox(height: 6),
                pw.Text(
                  'This report is generated automatically by the Nexora MediTwin system for '
                  'informational purposes only. It does not constitute medical advice, diagnosis, '
                  'or treatment. Always consult a qualified healthcare professional for medical decisions.',
                  style: pw.TextStyle(color: textMid, fontSize: 9, lineSpacing: 3),
                ),
              ]),
            ),

            pw.SizedBox(height: 20),
          ]),
        ),
      ],
    ));

    // ════════════════════════════════════════════════════════════════════
    // PAGE 2 — Signature
    // ════════════════════════════════════════════════════════════════════
    doc.addPage(pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        buildBackground: (_) => pw.Container(color: pageGrey),
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          buildHeader(),

          pw.SizedBox(height: 40),

          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: borderGrey, width: 0.8),
              ),
              padding: const pw.EdgeInsets.all(30),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _sigBlock('Attending Physician Signature', 'Signature & Stamp', textDark, textLight, borderGrey),
                  _sigBlock('Reviewed By', 'Name & Designation', textDark, textLight, borderGrey),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Report Date',
                        style: pw.TextStyle(
                          color: textMid, fontSize: 9, fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 8),
                    pw.Text(nowDate,
                        style: pw.TextStyle(
                          color: textDark, fontSize: 13, fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text('Time: $nowTime',
                        style: pw.TextStyle(color: textMid, fontSize: 9)),
                  ]),
                ],
              ),
            ),
          ),

          pw.Spacer(),

          pw.Container(
            color: white,
            padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.Container(
                    width: 14, height: 14,
                    decoration: pw.BoxDecoration(
                      color: nexoraBlue,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
                    ),
                    child: pw.Center(
                      child: pw.Text('N',
                          style: pw.TextStyle(color: white, fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Text('Nexora MediTwin   Confidential',
                      style: pw.TextStyle(color: textLight, fontSize: 8)),
                ]),
                pw.Text('Page 2 of 2',
                    style: pw.TextStyle(color: textLight, fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    ));

    return doc.save();
  }

  // ── Icon painters — drawn shapes, no Unicode ──────────────────────────────

  // Red heart shape
  static pw.CustomPainter _heartIconPainter(PdfColor color) {
    return (canvas, size) {
      canvas.setFillColor(color);
      // Two circles for top of heart
      canvas.drawEllipse(3.5, 8.5, 3.5, 3.5);
      canvas.fillPath();
      canvas.drawEllipse(8.5, 8.5, 3.5, 3.5);
      canvas.fillPath();
      // Triangle for bottom point
      canvas.moveTo(1, 8);
      canvas.lineTo(6, 1);
      canvas.lineTo(11, 8);
      canvas.closePath();
      canvas.fillPath();
    };
  }

  // Circle outline (SpO2)
  static pw.CustomPainter _circleIconPainter(PdfColor color) {
    return (canvas, size) {
      canvas.setStrokeColor(color);
      canvas.setLineWidth(1.5);
      canvas.drawEllipse(6, 6, 5, 5);
      canvas.strokePath();
    };
  }

  // Thermometer shape (temperature)
  static pw.CustomPainter _thermIconPainter(PdfColor color) {
    return (canvas, size) {
      canvas.setFillColor(color);
      // stick
      canvas.drawRect(4.5, 4, 3, 8);
      canvas.fillPath();
      // bulb
      canvas.drawEllipse(6, 3.5, 3.5, 3.5);
      canvas.fillPath();
      // inner white line
      canvas.setFillColor(PdfColors.white);
      canvas.drawRect(5.5, 5, 1, 7);
      canvas.fillPath();
    };
  }

  // ── Section label with left accent bar ───────────────────────────────────
  static pw.Widget _sectionLabel(String title, PdfColor color) =>
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Container(width: 4, height: 16, color: color),
        pw.SizedBox(width: 10),
        pw.Text(title.toUpperCase(),
            style: pw.TextStyle(
              color: color, fontSize: 10,
              fontWeight: pw.FontWeight.bold, letterSpacing: 1.2,
            )),
      ]);

  // ── Info tile: label + value ──────────────────────────────────────────────
  static pw.Widget _infoTile(String label, String value, PdfColor lc, PdfColor vc) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(color: lc, fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(color: vc, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]);

  // ── Vital card with drawn icon ────────────────────────────────────────────
  static pw.Widget _vitalCard({
    required String label,
    required String value,
    required String unit,
    required String status,
    required PdfColor accent,
    required pw.CustomPainter iconPainter,
    required PdfColor textDark,
    required PdfColor textLight,
    required PdfColor borderGrey,
  }) {
    final sBg = status == 'Normal'
        ? const PdfColor.fromInt(0xFFE8F5E9)
        : status == 'High'
            ? const PdfColor.fromInt(0xFFFFEBEE)
            : const PdfColor.fromInt(0xFFFFF8E1);
    final sFg = status == 'Normal'
        ? const PdfColor.fromInt(0xFF2E7D32)
        : status == 'High'
            ? const PdfColor.fromInt(0xFFC62828)
            : const PdfColor.fromInt(0xFFE65100);

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: borderGrey, width: 0.8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // Icon + label row
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.CustomPaint(
              size: const PdfPoint(12, 12),
              painter: iconPainter,
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(color: textLight, fontSize: 8)),
            ),
          ]),
          pw.SizedBox(height: 10),
          // Value + unit
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(value,
                style: pw.TextStyle(
                    color: textDark, fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 3),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(unit, style: pw.TextStyle(color: textLight, fontSize: 9)),
            ),
          ]),
          pw.SizedBox(height: 6),
          _statusBadge(status, sBg, sFg),
        ]),
      ),
    );
  }

  // ── HRV column ────────────────────────────────────────────────────────────
  static pw.Widget _hrvCol(String label, String value, PdfColor accent, PdfColor lc) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(color: lc, fontSize: 8)),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style: pw.TextStyle(
                color: accent, fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ]);

  // ── Status badge ──────────────────────────────────────────────────────────
  static pw.Widget _statusBadge(String text, PdfColor bg, PdfColor fg) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: fg, fontSize: 8, fontWeight: pw.FontWeight.bold)),
      );

  // ── Signature block ───────────────────────────────────────────────────────
  static pw.Widget _sigBlock(String title, String sub,
      PdfColor td, PdfColor tl, PdfColor border) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title,
            style: pw.TextStyle(
                color: td, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 30),
        pw.Container(width: 160, height: 0.8, color: border),
        pw.SizedBox(height: 4),
        pw.Text(sub, style: pw.TextStyle(color: tl, fontSize: 8)),
      ]);

  // ── Formatters ────────────────────────────────────────────────────────────
  static String _fmt(dynamic v) {
    if (v == null) return '--';
    final s = v.toString();
    if (s == '0' || s == '0.0') return '0';
    return s;
  }

  static String _vStatus(String value, num low, num high) {
    final v = double.tryParse(value);
    if (v == null || value == '--') return 'N/A';
    if (v < low)  return 'Low';
    if (v > high) return 'High';
    return 'Normal';
  }
}