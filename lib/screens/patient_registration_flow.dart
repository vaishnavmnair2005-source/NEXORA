import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui'; 
import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';
import 'main_screen.dart';
import 'biometric_lock.dart'; // ✅ For BiometricGatedPage wrapper
import 'legal_document_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

class PatientRegistrationFlow extends StatefulWidget {
  const PatientRegistrationFlow({super.key});

  @override
  State<PatientRegistrationFlow> createState() => _PatientRegistrationFlowState();
}

class _PatientRegistrationFlowState extends State<PatientRegistrationFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  int? _savedUserId;
  String? _generatedPatientId;
  String? _registeredEmail;
  bool _termsAccepted = false; // ← T&C checkbox state 

  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _mrdController = TextEditingController(); 
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController(); 
  final _dobController = TextEditingController(); 
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _historyController = TextEditingController();
  final _cgNameController = TextEditingController();
  final _cgRelationController = TextEditingController();
  final _cgPhoneController = TextEditingController();
  
  String? _selectedGender; 
  String? _selectedHospital;
  String? _selectedDoctor;
  String? _selectedBloodGroup;
  String? _selectedStatus;

  final List<String> _bloodGroups = ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"];
  
  final List<String> _statusOptions = [
    "Active (Stable)", "Critical Care (ICU)", "Under Observation", 
    "Post-Op Recovery", "Discharged", "Outpatient"
  ];

  final List<String> _hospitals = [
    "Amrita Hospital, Kochi", "Aster Medcity, Kochi", "KIMSHealth, Trivandrum",
    "Rajagiri Hospital, Kochi", "Medical Trust Hospital, Kochi", 
    "Baby Memorial Hospital, Kozhikode", "Lakeshore Hospital, Kochi", 
    "Lisie Hospital, Kochi", "Sree Chitra Tirunal, Trivandrum", "Renai Medicity, Kochi"
  ];

  final Map<String, List<String>> _hospitalDoctors = {
    "Amrita Hospital, Kochi": ["Dr. Hisham Ahamed (Cardiology)", "Dr. Anand Kumar A (Neurology)", "Dr. M.G.K. Pillai (General)"],
    "Aster Medcity, Kochi": ["Dr. Praveen Sreekumar (Cardiology)", "Dr. Sarath Menon (Neurology)", "Dr. Geetha Philips (General)"],
    "KIMSHealth, Trivandrum": ["Dr. G. Vijayaraghavan (Cardiology)", "Dr. Suresh Chandran (Neurology)", "Dr. P.K. Sasidharan (General)"],
    "Rajagiri Hospital, Kochi": ["Dr. Suresh Davis (Cardiology)", "Dr. Gigy Varkey (Neurology)", "Dr. Santhichandra Pai (General)"],
    "Medical Trust Hospital, Kochi": ["Dr. Sagy V. Kuruttukulam (Cardiology)", "Dr. Dilip Panicker (Neurology)", "Dr. P.V. Louis (General)"],
    "Baby Memorial Hospital, Kozhikode": ["Dr. Asokan Nambiar (Cardiology)", "Dr. James Jose (Neurology)", "Dr. Feroz Aziz (General)"],
    "Lakeshore Hospital, Kochi": ["Dr. Anand Kumar (Cardiology)", "Dr. Murali Krishna (Neurology)", "Dr. Sudhayakumar N (General)"],
    "Lisie Hospital, Kochi": ["Dr. Jo Joseph (Cardiology)", "Dr. Mathew Abraham (Neurology)", "Dr. Babu Francis (General)"],
    "Sree Chitra Tirunal, Trivandrum": ["Dr. Ajit Kumar V (Cardiology)", "Dr. Sanjeev V. Thomas (Neurology)", "Dr. R. Lakshmi (General)"],
    "Renai Medicity, Kochi": ["Dr. Thomas Paul (Cardiology)", "Dr. Dinesh Nayak (Neurology)", "Dr. Ravi K (General)"],
  };

  @override
  void initState() {
    super.initState();
    // SplashRouter in main.dart handles login-status routing — no check needed here
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _mrdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _historyController.dispose();
    _cgNameController.dispose();
    _cgRelationController.dispose();
    _cgPhoneController.dispose();
    super.dispose();
  }

  void _moveToNext() {
    // 🔥 UPDATED: Fast 250ms transition for snappiness
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    setState(() => _currentStep++);
  }

  void _handleNextButton() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState!.validate()) {
        if (_registeredEmail != null && _emailController.text.trim() == _registeredEmail) {
          _moveToNext(); 
        } else {
          _processStep1Account();
        }
      }
    } else if (_currentStep == 1) {
      if (_formKeyStep2.currentState!.validate()) {
        if (_selectedGender == null) {
          _showError("Please select a gender");
        } else {
          _processStep2Personal();
        }
      }
    } else if (_currentStep == 2) {
      if (_formKeyStep3.currentState!.validate()) {
        if (_selectedHospital == null || _selectedDoctor == null) {
          _showError("Hospital and Doctor selection required");
        } else if (!_termsAccepted) {
          _showTermsAlert();
        } else {
          _processStep3MedicalAndFinish();
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, onPrimary: Colors.white, surface: Color(0xFF1E1E1E)),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
        ), 
        child: child!
      ),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showTermsAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.gavel_rounded, color: Colors.amber, size: 40),
        title: const Text(
          'Accept Terms to Continue',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You must read and accept the Terms of Service and Privacy Policy before creating your account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // 🔥 UPDATED FUNCTION WITH REAL ERROR HANDLING
  Future<void> _processStep1Account() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/app/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passController.text, // Not trimmed so spaces aren't lost if used intentionally
          'mrd_number': _mrdController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _savedUserId = data['user_id'];
        _registeredEmail = _emailController.text.trim();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('logged_in_user_id', _savedUserId!);
        
        _moveToNext();
      } else {
        // 🔥 Ask the Python backend what ACTUALLY went wrong!
        String realErrorMessage = "Signup failed (Error ${response.statusCode})";
        try {
          final errorData = jsonDecode(response.body);
          
          // FastAPI usually puts errors inside 'detail'
          if (errorData['detail'] is String) {
            realErrorMessage = errorData['detail'];
          } 
          // If it's a Pydantic Validation Error (like extra fields or wrong data types)
          else if (errorData['detail'] is List) {
            realErrorMessage = "Format Error: ${errorData['detail'][0]['loc'].last} - ${errorData['detail'][0]['msg']}";
          } 
          else if (errorData['message'] != null) {
            realErrorMessage = errorData['message'];
          }
        } catch (_) {}

        // Show the REAL error on the screen
        _showError(realErrorMessage);
      }
    } catch (e) {
      _showError("Connection Error: Check if server is running");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processStep2Personal() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/app/personal-info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _savedUserId,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'gender': _selectedGender,
          'dob': _dobController.text.trim(),
          'contact_number': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _generatedPatientId = data['patient_id'];
        _moveToNext();
      }
    } catch (e) {
      _showError("Failed to save personal info");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processStep3MedicalAndFinish() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/app/medical-caregiver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _savedUserId,
          'hospital': _selectedHospital,
          'doctor': _selectedDoctor,
          'blood_group': _selectedBloodGroup,
          'current_status': _selectedStatus,
          'medical_history': _historyController.text.trim(),
          'cg_full_name': _cgNameController.text.trim(),
          'cg_relation': _cgRelationController.text.trim(),
          'cg_phone': _cgPhoneController.text.trim(),
          'cg_is_primary': true,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(); 
      } else {
         _showError("Final submission failed");
      }
    } catch (e) {
      _showError("Connection Error");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("System Initialized", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
            const SizedBox(height: 20),
            const Text(
              "Please save your Patient ID. You will need it to pair your device.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                _generatedPatientId ?? "Error",
                style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BiometricGatedPage(
                      child: MainScreen(userId: _savedUserId!),
                    ),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text("Go to Dashboard", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.topCenter, radius: 1.5, colors: [Color(0xFF1A237E), Color(0xFF000000)], stops: [0.0, 0.8]))),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                if (_currentStep == 0) ...[
                  const Icon(Icons.health_and_safety, size: 50, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text("NEXORA MEDITWIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
                ],
                const SizedBox(height: 20),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: LinearProgressIndicator(value: (_currentStep + 1) / 3, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(AppColors.primary)),
                ),
                
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _stepWrapper("Initialize Identity", _buildStep1()),
                      _stepWrapper("Personal Profile", _buildStep2()),
                      _stepWrapper("Health Baseline", _buildStep3()),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: GradientButton(
                    text: _currentStep == 2 ? "Finalize Twin" : "Continue",
                    isLoading: _isLoading,
                    onPressed: _handleNextButton,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepWrapper(String title, Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        children: [
          CustomTextField(
            hint: "Email", icon: Icons.email_outlined, controller: _emailController, 
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-\.]+@gmail\.com$').hasMatch(v.trim())) return 'Please enter a valid @gmail.com address';
              return null;
            }
          ),
          const SizedBox(height: 16),
          // 🔥 STRICT PASSWORD VALIDATION
          CustomTextField(
            hint: "Password", icon: Icons.lock_outline, controller: _passController, isPassword: true, 
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              // Regex: At least 1 lower, 1 upper, 1 digit, 1 special char, 8-16 length
              if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#])[A-Za-z\d@$!%*?&#]{8,16}$').hasMatch(v)) {
                return '8-16 chars, 1 Uppercase, 1 Number, 1 Special Char (@\$!%*?&#)';
              }
              return null;
            }
          ),
          const SizedBox(height: 16),
          CustomTextField(hint: "MRD Number", icon: Icons.folder, controller: _mrdController, validator: (v) => (v == null || v.trim().isEmpty) ? "MRD is required" : null),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        children: [
          CustomTextField(hint: "First Name", icon: Icons.person, controller: _firstNameController, validator: (v) => (v != null && RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) ? null : "Alphabets only"),
          const SizedBox(height: 16),
          CustomTextField(hint: "Last Name", icon: Icons.person_outline, controller: _lastNameController, validator: (v) => (v != null && RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) ? null : "Alphabets only"),
          const SizedBox(height: 16),
          _buildDropdown("Gender", ["Male", "Female", "Other"], (v) => setState(() => _selectedGender = v), Icons.wc),
          const SizedBox(height: 16),
          GestureDetector(onTap: () => _selectDate(context), child: AbsorbPointer(child: CustomTextField(hint: "DOB (yyyy-mm-dd)", icon: Icons.calendar_today, controller: _dobController, validator: (v) => v!.isEmpty ? "Required" : null))),
          const SizedBox(height: 16),
          CustomTextField(hint: "Phone", icon: Icons.phone, controller: _phoneController, validator: (v) => (v != null && v.length == 10 && RegExp(r'^[0-9]+$').hasMatch(v)) ? null : "10 digits required"),
          const SizedBox(height: 16),
          CustomTextField(hint: "Address", icon: Icons.home, controller: _addressController, maxLines: 2, validator: (v) => v!.isEmpty ? "Required" : null),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _formKeyStep3,
      child: Column(
        children: [
          _buildDropdown("Select Hospital", _hospitals, (v) => setState(() { _selectedHospital = v; _selectedDoctor = null; }), Icons.local_hospital),
          const SizedBox(height: 16),
          if (_selectedHospital != null) ...[
            _buildDropdown("Select Doctor", _hospitalDoctors[_selectedHospital]!, (v) => setState(() => _selectedDoctor = v), Icons.medical_services),
            const SizedBox(height: 16),
          ],
          _buildDropdown("Blood Group", _bloodGroups, (v) => setState(() => _selectedBloodGroup = v), Icons.bloodtype),
          const SizedBox(height: 16),
          _buildDropdown("Current Status", _statusOptions, (v) => setState(() => _selectedStatus = v), Icons.monitor_heart),
          const SizedBox(height: 16),
          CustomTextField(hint: "Medical History", icon: Icons.history, controller: _historyController),
          const SizedBox(height: 24),
          const Text("Caregiver Info", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          CustomTextField(hint: "Caregiver Name", icon: Icons.person_add, controller: _cgNameController, validator: (v) => (v != null && RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) ? null : "Alphabets only"),
          const SizedBox(height: 16),
          CustomTextField(hint: "Relationship", icon: Icons.people, controller: _cgRelationController, validator: (v) => (v != null && RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) ? null : "Alphabets only"),
          const SizedBox(height: 16),
          CustomTextField(hint: "Caregiver Phone", icon: Icons.phone_callback, controller: _cgPhoneController, validator: (v) => (v != null && v.length == 10 && RegExp(r'^[0-9]+$').hasMatch(v)) ? null : "10 digits required"),
          
          const SizedBox(height: 24),

          // ── TERMS & CONDITIONS CHECKBOX ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _termsAccepted
                  ? AppColors.primary.withOpacity(0.08)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _termsAccepted
                    ? AppColors.primary.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                  activeColor: AppColors.primary,
                  checkColor: Colors.white,
                  side: BorderSide(color: Colors.white38, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        children: [
                          const TextSpan(text: 'I have read and agree to the '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LegalDocumentScreen(type: LegalDocType.terms),
                                ),
                              ),
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LegalDocumentScreen(type: LegalDocType.privacy),
                                ),
                              ),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' of NEXORA MediTwin.'),
                        ],
                      ),
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

  Widget _buildDropdown(String hint, List<String> items, Function(String?) onChanged, IconData icon) {
    return DropdownButtonFormField<String>(
      dropdownColor: const Color(0xFF1A1A1A),
      style: const TextStyle(color: Colors.white),
      items: items.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged as void Function(String?)?,
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white54), prefixIcon: Icon(icon, color: AppColors.primary), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    );
  }
}