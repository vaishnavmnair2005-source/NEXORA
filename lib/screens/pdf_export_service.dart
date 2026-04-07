import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PDF EXPORT SERVICE
// Generates a branded patient health report as a PDF.
// Dependencies to add in pubspec.yaml:
//   pdf: ^3.10.4
//   printing: ^5.11.0
//   path_provider: ^2.1.1
//   intl: ^0.18.1
// ─────────────────────────────────────────────────────────────────────────────

class PdfExportService {
  /// Generates and opens the share/print dialog for the health report.
  static Future<void> exportAndShare({
    required BuildContext context,
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> vitals,
    List<Map<String, dynamic>>? historyRecords,
  }) async {
    // ✅ Block export if device not paired
    final deviceId = userProfile['device_id'];
    if (deviceId == null || (deviceId as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.link_off, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No device paired. Please pair your Bio-Patch before exporting a report.',
            ),
          ),
        ]),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    try {
      _showLoadingToast(context, 'Generating report...');
      final bytes = await _buildPdf(
          userProfile: userProfile,
          vitals: vitals,
          historyRecords: historyRecords ?? []);

      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'MediTwin_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  /// Saves PDF to device storage and returns the file path.
  static Future<String?> saveToDevice({
    required BuildContext context,
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> vitals,
    List<Map<String, dynamic>>? historyRecords,
  }) async {
    try {
      final bytes = await _buildPdf(
          userProfile: userProfile,
          vitals: vitals,
          historyRecords: historyRecords ?? []);

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'MediTwin_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('PDF save error: $e');
      return null;
    }
  }

  // ─── INTERNAL PDF BUILDER ──────────────────────────────────────────────────
  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> vitals,
    required List<Map<String, dynamic>> historyRecords,
  }) async {
    final doc = pw.Document();

    // Colors
    const nexoraBlue = PdfColor.fromInt(0xFF00B4CC);
    const darkBg = PdfColor.fromInt(0xFF050D1F);
    const cardBg = PdfColor.fromInt(0xFF0A1628);
    const textLight = PdfColor.fromInt(0xFFFFFFFF);
    const textMuted = PdfColor.fromInt(0xFF94A3B8);
    const accentGreen = PdfColor.fromInt(0xFF22C55E);
    const accentRed = PdfColor.fromInt(0xFFEF4444);
    const accentAmber = PdfColor.fromInt(0xFFF59E0B);

    // Patient info
    final fullName =
        '${userProfile['first_name'] ?? ''} ${userProfile['last_name'] ?? ''}'
            .trim();
    final patientId = userProfile['patient_id'] ?? 'N/A';
    final mrdNumber = userProfile['mrd_number'] ?? 'N/A';
    final email = userProfile['email'] ?? 'N/A';
    final dob = userProfile['dob'] ?? 'N/A';
    final gender = userProfile['gender'] ?? 'N/A';
    final phone = userProfile['contact_number'] ?? 'N/A';
    final bloodGroup = userProfile['blood_group'] ?? 'N/A';
    final deviceId = userProfile['device_id'] ?? 'Not paired';

    // Vitals
    final bpm = vitals['bpm']?.toString() ?? '--';
    final spo2 = vitals['spo2']?.toString() ?? '--';
    final hrv = vitals['hrv']?.toString() ?? '--';
    final temp = vitals['temp']?.toString() ?? '--';
    final gsr = vitals['gsr']?.toString() ?? 'Normal';
    final fallStatus = vitals['fall_status']?.toString() ?? 'Safe';

    final now = DateFormat('MMMM dd, yyyy — HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          buildBackground: (context) => pw.Container(color: darkBg),
        ),
        build: (ctx) => [
          // ── HEADER BAR ──────────────────────────────────────────────
          pw.Container(
            color: cardBg,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 22),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NEXORA MEDITWIN',
                        style: pw.TextStyle(
                          color: nexoraBlue,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Patient Health Report',
                        style: pw.TextStyle(
                            color: textMuted, fontSize: 12),
                      ),
                    ]),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        now,
                        style: pw.TextStyle(
                            color: textMuted, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: nexoraBlue.shade(0.15),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          patientId,
                          style: pw.TextStyle(
                            color: nexoraBlue,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ]),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── BODY ─────────────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // PATIENT INFO
                _pdfSectionLabel('Patient Information', nexoraBlue),
                pw.SizedBox(height: 12),
                _pdfCard(
                  cardBg,
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfRow('Full Name', fullName, textLight,
                                textMuted),
                            pw.SizedBox(height: 10),
                            _pdfRow('Date of Birth', dob, textLight, textMuted),
                            pw.SizedBox(height: 10),
                            _pdfRow('Gender', gender, textLight, textMuted),
                            pw.SizedBox(height: 10),
                            _pdfRow('Blood Group', bloodGroup, textLight,
                                textMuted),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfRow('Email', email, textLight, textMuted),
                            pw.SizedBox(height: 10),
                            _pdfRow('Phone', phone, textLight, textMuted),
                            pw.SizedBox(height: 10),
                            _pdfRow('MRD Number', mrdNumber, textLight,
                                textMuted),
                            pw.SizedBox(height: 10),
                            _pdfRow('Bio-Patch ID', deviceId, textLight,
                                textMuted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // CURRENT VITALS
                _pdfSectionLabel('Current Vitals Snapshot', nexoraBlue),
                pw.SizedBox(height: 12),
                pw.Row(children: [
                  _pdfVitalCard('Heart Rate', bpm, 'bpm',
                      _vitalStatus(bpm, 60, 100), cardBg),
                  pw.SizedBox(width: 12),
                  _pdfVitalCard('SpO₂', spo2, '%',
                      _vitalStatus(spo2, 95, 100), cardBg),
                  pw.SizedBox(width: 12),
                  _pdfVitalCard('HRV', hrv, 'ms',
                      _vitalStatus(hrv, 20, 200), cardBg),
                ]),
                pw.SizedBox(height: 12),
                pw.Row(children: [
                  _pdfVitalCard(
                      'Temperature', temp, '°C',
                      _vitalStatus(temp, 36.0, 37.5), cardBg),
                  pw.SizedBox(width: 12),
                  _pdfVitalCard('Stress Level', gsr, '',
                      gsr == 'Normal' ? 'Normal' : 'Elevated', cardBg),
                  pw.SizedBox(width: 12),
                  _pdfVitalCard('Fall Status', fallStatus, '',
                      fallStatus == 'Safe' ? 'Normal' : 'Alert', cardBg),
                ]),

                // History table (if any)
                if (historyRecords.isNotEmpty) ...[
                  pw.SizedBox(height: 24),
                  _pdfSectionLabel('Vitals History (Last 10)', nexoraBlue),
                  pw.SizedBox(height: 12),
                  _pdfCard(
                    cardBg,
                    pw.Table(
                      border: pw.TableBorder.all(
                          color: PdfColors.white,
                          width: 0.2,
                          style: pw.BorderStyle.solid),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                              color: nexoraBlue.shade(0.2)),
                          children: ['Timestamp', 'BPM', 'SpO₂', 'Temp', 'HRV']
                              .map((h) => pw.Padding(
                                    padding: const pw.EdgeInsets.all(8),
                                    child: pw.Text(h,
                                        style: pw.TextStyle(
                                            color: textLight,
                                            fontSize: 10,
                                            fontWeight:
                                                pw.FontWeight.bold)),
                                  ))
                              .toList(),
                        ),
                        ...historyRecords.take(10).map((r) => pw.TableRow(
                              children: [
                                r['timestamp']?.toString() ?? '--',
                                r['bpm']?.toString() ?? '--',
                                r['spo2']?.toString() ?? '--',
                                r['temp']?.toString() ?? '--',
                                r['hrv']?.toString() ?? '--',
                              ]
                                  .map((v) => pw.Padding(
                                        padding: const pw.EdgeInsets.all(8),
                                        child: pw.Text(v,
                                            style: pw.TextStyle(
                                                color: textMuted,
                                                fontSize: 10)),
                                      ))
                                  .toList(),
                            )),
                      ],
                    ),
                  ),
                ],

                pw.SizedBox(height: 24),

                // DISCLAIMER
                _pdfCard(
                  cardBg,
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Medical Disclaimer',
                          style: pw.TextStyle(
                              color: accentAmber,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11)),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'This report is generated automatically by the Nexora MediTwin system for informational purposes only. '
                        'It does not constitute medical advice, diagnosis, or treatment. '
                        'Always consult a qualified healthcare professional for medical decisions.',
                        style: pw.TextStyle(color: textMuted, fontSize: 10, lineSpacing: 4),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),
              ],
            ),
          ),
        ],

        footer: (ctx) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Nexora MediTwin — Confidential',
                  style: pw.TextStyle(
                      color: textMuted, fontSize: 9)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      color: textMuted, fontSize: 9)),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  // ─── WIDGET BUILDERS ────────────────────────────────────────────────────────
  static pw.Widget _pdfSectionLabel(String title, PdfColor color) {
    return pw.Row(children: [
      pw.Container(width: 4, height: 16, color: color),
      pw.SizedBox(width: 10),
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.5),
      ),
    ]);
  }

  static pw.Widget _pdfCard(PdfColor bg, pw.Widget child) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: child,
    );
  }

  static pw.Widget _pdfRow(
      String label, String value, PdfColor valueColor, PdfColor labelColor) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(color: labelColor, fontSize: 9)),
      pw.SizedBox(height: 2),
      pw.Text(value,
          style: pw.TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold)),
    ]);
  }

  static pw.Widget _pdfVitalCard(
      String label, String value, String unit, String status, PdfColor bg) {
    final statusColor = status == 'Normal'
        ? const PdfColor.fromInt(0xFF22C55E)
        : status == 'Elevated' || status == 'Alert'
            ? const PdfColor.fromInt(0xFFEF4444)
            : const PdfColor.fromInt(0xFFF59E0B);

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFF94A3B8),
                    fontSize: 9)),
            pw.SizedBox(height: 6),
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      color: const PdfColor.fromInt(0xFFFFFFFF),
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold)),
              if (unit.isNotEmpty) ...[
                pw.SizedBox(width: 3),
                pw.Text(unit,
                    style: pw.TextStyle(
                        color: const PdfColor.fromInt(0xFF94A3B8),
                        fontSize: 9)),
              ],
            ]),
            pw.SizedBox(height: 6),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: statusColor.shade(0.15),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(status,
                  style: pw.TextStyle(
                      color: statusColor,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static String _vitalStatus(String value, num low, num high) {
    final v = double.tryParse(value);
    if (v == null) return 'N/A';
    if (v < low) return 'Low';
    if (v > high) return 'High';
    return 'Normal';
  }

  static void _showLoadingToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(message),
      ]),
      backgroundColor: const Color(0xFF0A1628),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT BUTTON WIDGET
// Drop-in button that calls PdfExportService.exportAndShare()
// ─────────────────────────────────────────────────────────────────────────────
class ExportPdfButton extends StatelessWidget {
  final Map<String, dynamic> userProfile;
  final Map<String, dynamic> vitals;
  final List<Map<String, dynamic>>? historyRecords;

  const ExportPdfButton({
    super.key,
    required this.userProfile,
    required this.vitals,
    this.historyRecords,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => PdfExportService.exportAndShare(
        context: context,
        userProfile: userProfile,
        vitals: vitals,
        historyRecords: historyRecords,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.8),
              AppColors.primary.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Export Report',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}