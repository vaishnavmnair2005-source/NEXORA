import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEGAL DOCUMENT SCREEN
// Renders Terms of Service and Privacy Policy natively in-app.
// No WebView plugin needed — everything is Flutter widgets.
// ─────────────────────────────────────────────────────────────────────────────

enum LegalDocType { terms, privacy }

class LegalDocumentScreen extends StatefulWidget {
  final LegalDocType type;
  const LegalDocumentScreen({super.key, required this.type});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  bool get _isTerms => widget.type == LegalDocType.terms;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!mounted) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max > 0) {
        setState(() => _scrollProgress =
            _scrollController.offset.clamp(0, max) / max);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060D1E),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.3,
                colors: [Color(0xFF0D1B3E), Color(0xFF000000)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────
                _buildHeader(),

                // ── Scroll progress bar ───────────────────────────────
                LinearProgressIndicator(
                  value: _scrollProgress,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _isTerms ? AppColors.primary : Colors.greenAccent),
                  minHeight: 2,
                ),

                // ── Content ───────────────────────────────────────────
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: _isTerms
                        ? _buildTermsContent()
                        : _buildPrivacyContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 16),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_isTerms ? AppColors.primary : Colors.greenAccent)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isTerms ? Icons.gavel_rounded : Icons.shield_outlined,
                  color: _isTerms ? AppColors.primary : Colors.greenAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTerms ? 'Terms of Service' : 'Privacy Policy',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Text(
                      _isTerms
                          ? 'Effective January 1, 2025 · v3.1.0'
                          : 'Effective January 1, 2025 · v2.4.0',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Scroll % badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isTerms ? AppColors.primary : Colors.greenAccent)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_scrollProgress * 100).round()}%',
                  style: TextStyle(
                    color: _isTerms ? AppColors.primary : Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TERMS OF SERVICE CONTENT ──────────────────────────────────────────────
  List<Widget> _buildTermsContent() {
    return [
      _heroBadge('Legally Binding Agreement', Icons.gavel_rounded,
          AppColors.primary),
      const SizedBox(height: 20),

      _alertBox(
        icon: Icons.warning_amber_rounded,
        color: Colors.amber,
        title: 'Important Medical Disclaimer',
        body:
            'NEXORA MediTwin is a monitoring and wellness tool ONLY. It does NOT provide medical diagnoses, treatment plans, or clinical advice. Always consult a qualified healthcare professional for all medical decisions.',
      ),
      const SizedBox(height: 24),

      _section('1. Acceptance of Terms', Icons.handshake_outlined,
          AppColors.primary, [
        _paragraph(
            'By creating an account, pairing a device, or using any feature of NEXORA MediTwin ("Platform"), you ("User") agree to be bound by these Terms of Service. If you do not agree, you must immediately discontinue use.'),
        _paragraph(
            'These Terms constitute a legally binding agreement between you and NEXORA Technologies Inc. Last updated: January 19, 2026.'),
      ]),

      _section('2. Definitions', Icons.menu_book_outlined, Colors.cyanAccent, [
        _definitionRow('Platform',
            'The NEXORA MediTwin mobile application and all associated cloud services.'),
        _definitionRow('Bio-Patch',
            'The ESP-32 based wearable IoT device provided by or compatible with NEXORA.'),
        _definitionRow('Digital Twin',
            'The AI-generated real-time virtual model of your health state.'),
        _definitionRow('Health Data',
            'All biometric readings, vitals, and health-related information collected through the Platform.'),
        _definitionRow('Caregiver',
            'A designated individual authorized to receive emergency health alerts on your behalf.'),
      ]),

      _section('3. Eligibility', Icons.person_outlined, Colors.tealAccent, [
        _paragraph(
            'You must be at least 18 years of age or using the Platform under the supervision of a parent or legal guardian. You must provide accurate registration information and maintain a valid linked healthcare provider.'),
      ]),

      _section('4. Device Usage', Icons.memory_outlined, Colors.blueAccent, [
        _paragraph(
            'The Bio-Patch device must be used only as directed in the product manual. NEXORA is not liable for inaccurate readings caused by improper placement, environmental interference, or hardware damage.'),
        _bulletPoint(
            'Device must be worn on the wrist or chest as instructed.'),
        _bulletPoint(
            'Firmware updates must be applied promptly when available.'),
        _bulletPoint(
            'Tampering with or modifying the device voids all warranties.'),
      ]),

      _section('5. Health Data & AI Limitations', Icons.auto_awesome_outlined,
          Colors.purpleAccent, [
        _paragraph(
            'The AI-generated health insights are statistical models and carry an inherent margin of error. They are intended to supplement, not replace, professional medical advice.'),
        _alertBox(
          icon: Icons.info_outline,
          color: Colors.blueAccent,
          title: 'AI Confidence Levels',
          body:
              'All AI predictions and alerts include confidence scores. A score below 85% should be interpreted with additional clinical context.',
        ),
      ]),

      _section('6. Account Terms', Icons.lock_outlined, Colors.orangeAccent, [
        _paragraph(
            'You are responsible for maintaining the confidentiality of your account credentials. You must notify NEXORA immediately at security@nexora.health if you suspect unauthorized access.'),
        _paragraph(
            'NEXORA reserves the right to suspend accounts that violate these Terms, exhibit suspicious activity, or pose a risk to other users or systems.'),
      ]),

      _section('7. Data Rights', Icons.storage_outlined, Colors.greenAccent, [
        _paragraph(
            'You retain full ownership of your personal health data. By using the Platform, you grant NEXORA a limited, non-exclusive licence to process your data solely to provide the services described herein.'),
        _paragraph(
            'You may request deletion of your account and all associated data at any time through Settings → Account → Delete Account.'),
      ]),

      _section('8. Prohibited Uses', Icons.block_outlined, Colors.redAccent, [
        _bulletPoint(
            'Sharing account credentials with unauthorized individuals.'),
        _bulletPoint(
            'Using the Platform for any commercial resale or redistribution.'),
        _bulletPoint(
            'Attempting to reverse-engineer, decompile, or extract AI models.'),
        _bulletPoint('Submitting false or misleading health information.'),
        _bulletPoint(
            'Using the SOS system in non-emergency situations (misuse is subject to account termination).'),
      ]),

      _section('9. Warranties & Liability', Icons.gpp_maybe_outlined,
          Colors.amber, [
        _alertBox(
          icon: Icons.warning_amber_rounded,
          color: Colors.amber,
          title: 'No Medical Warranty',
          body:
              'THE PLATFORM IS PROVIDED "AS IS". NEXORA MAKES NO WARRANTY THAT THE PLATFORM WILL DIAGNOSE, TREAT, CURE, OR PREVENT ANY MEDICAL CONDITION.',
        ),
        _paragraph(
            'To the maximum extent permitted by law, NEXORA\'s total liability to you for any claim shall not exceed the subscription fees paid by you in the 12 months preceding the claim.'),
      ]),

      _section('10. Governing Law', Icons.account_balance_outlined,
          Colors.white60, [
        _paragraph(
            'These Terms shall be governed by the laws of the State of California, United States, without regard to its conflict of law provisions. Any disputes shall be resolved through binding arbitration in San Francisco County, CA.'),
      ]),

      const SizedBox(height: 32),
      _footerCard(
          'By using NEXORA MediTwin, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
          'Thank you for choosing NEXORA. Together, we\'re building the future of personalized healthcare.'),
    ];
  }

  // ── PRIVACY POLICY CONTENT ────────────────────────────────────────────────
  List<Widget> _buildPrivacyContent() {
    return [
      _heroBadge('HIPAA & GDPR Compliant', Icons.shield_outlined,
          Colors.greenAccent),
      const SizedBox(height: 20),

      _alertBox(
        icon: Icons.verified_user_outlined,
        color: Colors.greenAccent,
        title: 'Your Health Data is Protected',
        body:
            'NEXORA MediTwin applies AES-256 encryption at rest and TLS 1.3 in transit. We are HIPAA-compliant and follow GDPR principles for all EU/UK users.',
      ),
      const SizedBox(height: 24),

      _section('1. Introduction', Icons.info_outline, Colors.greenAccent, [
        _paragraph(
            'NEXORA Technologies Inc. ("we", "us", "NEXORA") is committed to protecting your health and personal data. This Privacy Policy explains what data we collect, why we collect it, and how we safeguard it.'),
        _paragraph(
            'This policy applies to all users of the NEXORA MediTwin mobile application and associated hardware (Bio-Patch). Effective date: January 1, 2025. Last updated: January 19, 2026.'),
      ]),

      _section('2. Data We Collect', Icons.radar_outlined, Colors.cyanAccent, [
        _dataRow(Icons.person, 'Identity Data',
            'Name, email address, date of birth, gender, and MRD number.'),
        _dataRow(Icons.monitor_heart, 'Health & Biometric Data',
            'Heart rate, SpO₂, ECG traces, temperature, HRV, fall detection events, and stress levels from your Bio-Patch.'),
        _dataRow(Icons.location_on_outlined, 'Emergency Location',
            'Approximate location shared with your caregiver during SOS events only.'),
        _dataRow(Icons.smartphone_outlined, 'Device & Usage Data',
            'App version, device OS, session duration, and feature usage analytics (anonymised).'),
        _dataRow(Icons.medical_services_outlined, 'Medical Information',
            'Hospital name, assigned doctor, blood group, current clinical status, and medical history you voluntarily provide.'),
      ]),

      _section('3. How We Use Your Data', Icons.settings_suggest_outlined,
          Colors.tealAccent, [
        _bulletPoint('To generate and maintain your personal Digital Twin.'),
        _bulletPoint(
            'To detect vital anomalies and trigger emergency SOS alerts.'),
        _bulletPoint(
            'To generate health trend reports and AI-powered insights.'),
        _bulletPoint(
            'To send notifications to your designated caregiver in emergencies.'),
        _bulletPoint('To improve our AI models (using anonymised data only).'),
        _alertBox(
          icon: Icons.block_outlined,
          color: Colors.redAccent,
          title: 'We Never Sell Your Data',
          body:
              'NEXORA does not and will never sell, rent, or trade your personal or health data to third parties for advertising, marketing, or commercial purposes.',
        ),
      ]),

      _section('4. Security Measures', Icons.security_outlined, Colors.blueAccent, [
        _securityRow('AES-256 Encryption',
            'All stored health data is encrypted at rest.'),
        _securityRow('TLS 1.3 Transit',
            'All data in transit is secured with TLS 1.3.'),
        _securityRow('Zero-Knowledge Logs',
            'Support staff cannot view raw biometric readings.'),
        _securityRow('Biometric Lock',
            'App supports fingerprint and Face ID authentication.'),
        _securityRow('Regular Audits',
            'Annual third-party security penetration testing.'),
      ]),

      _section('5. Data Sharing', Icons.share_outlined, Colors.orangeAccent, [
        _paragraph(
            'We share your data only in the following limited circumstances:'),
        _bulletPoint(
            'With your designated Primary Caregiver — emergency alerts only.'),
        _bulletPoint(
            'With your assigned hospital/doctor — only if you explicitly grant access.'),
        _bulletPoint(
            'With law enforcement — only when legally compelled by court order.'),
        _bulletPoint(
            'With cloud infrastructure providers (AWS / GCP) — under strict data processing agreements.'),
      ]),

      _section('6. Your Rights', Icons.admin_panel_settings_outlined,
          Colors.purpleAccent, [
        _rightRow('Access', 'Request a full copy of your stored health data.'),
        _rightRow('Correction',
            'Correct any inaccurate personal or health information.'),
        _rightRow('Erasure',
            'Request complete deletion of your account and all associated data.'),
        _rightRow('Portability',
            'Export your health data in JSON or PDF format.'),
        _rightRow('Restriction',
            'Limit how we process your data for specific purposes.'),
        _rightRow('Objection',
            'Object to AI-based processing of your health data.'),
      ]),

      _section('7. Data Retention', Icons.history_outlined, Colors.white60, [
        _paragraph(
            'Your data is retained for as long as your account remains active. Upon account deletion, all personal and health data is permanently purged within 30 days from all our systems and backups.'),
      ]),

      _section('8. HIPAA Compliance', Icons.local_hospital_outlined,
          Colors.greenAccent, [
        _paragraph(
            'For users in the United States, NEXORA operates as a Business Associate under HIPAA regulations. We maintain HIPAA-compliant data handling practices including signed Business Associate Agreements (BAAs) with all sub-processors.'),
      ]),

      _section('9. GDPR Compliance', Icons.flag_outlined, Colors.blueAccent, [
        _paragraph(
            'For users in the European Union or United Kingdom, NEXORA complies with the General Data Protection Regulation (GDPR) and UK GDPR. Our lawful bases for processing are: (i) contractual necessity, (ii) legitimate interests, and (iii) explicit consent.'),
      ]),

      _section('10. Contact & DPO', Icons.contact_mail_outlined, Colors.cyanAccent, [
        _paragraph(
            'For all privacy-related enquiries, data requests, or to reach our Data Protection Officer:'),
        _contactRow(Icons.email_outlined, 'privacy@nexora.health'),
        _contactRow(Icons.language_outlined, 'www.nexora.health/privacy'),
        _contactRow(Icons.location_on_outlined,
            'NEXORA Technologies Inc., 123 Innovation Dr, San Francisco, CA 94105'),
      ]),

      const SizedBox(height: 32),
      _footerCard(
          'Your health. Your data. Your control. NEXORA is committed to transparency and putting patients first in every decision we make.',
          'Last updated January 19, 2026. Version 2.4.0.'),
    ];
  }

  // ── WIDGET HELPERS ────────────────────────────────────────────────────────
  Widget _heroBadge(String label, IconData icon, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color,
      List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(
                bottom:
                    BorderSide(color: color.withOpacity(0.15))),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.3)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ]),
    );
  }

  Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13.5, height: 1.65)),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13.5, height: 1.5)),
        ),
      ]),
    );
  }

  Widget _alertBox(
      {required IconData icon,
      required Color color,
      required String title,
      required String body}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        // left accent
        boxShadow: [BoxShadow(color: color.withOpacity(0.0))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 12.5, height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _definitionRow(String term, String def) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(term,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        Expanded(
          child: Text(def,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _dataRow(IconData icon, String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.cyanAccent, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(desc,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12.5, height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  Widget _securityRow(String label, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: '$label — ',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              TextSpan(
                  text: desc,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _rightRow(String right, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
          ),
          child: Text(right,
              style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(desc,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.cyanAccent, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _footerCard(String body, String sub) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.12),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(children: [
        const Icon(Icons.verified_outlined, color: AppColors.primary, size: 32),
        const SizedBox(height: 12),
        Text(body,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.55)),
        const SizedBox(height: 8),
        Text(sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}