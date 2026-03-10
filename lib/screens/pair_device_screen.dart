import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientIdController = TextEditingController();
  final _deviceIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitPairing() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/app/pair-device"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "patient_id": _patientIdController.text.trim(),
          "device_id": _deviceIdController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Device Paired Successfully!"), backgroundColor: Colors.green)
          );
          Navigator.pop(context); // Go back to the dashboard after success
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection Failed. Is your server running?"), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Pair Hardware", style: AppTextStyles.heading1),
                const SizedBox(height: 10),
                const Text("Enter your details to link the Bio-Patch.", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 40),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.faceCard, 
                    borderRadius: BorderRadius.circular(28)
                  ),
                  child: Column(
                    children: [
                      CustomTextField(
                        hint: "Patient ID (e.g. PT-1234)", 
                        icon: Icons.badge, 
                        controller: _patientIdController, 
                        validator: (v) => v!.isEmpty ? "Required" : null
                      ),
                      const SizedBox(height: 20),
                      
                      // FIXED: This now says exactly "Device ID"
                      CustomTextField(
                        hint: "Device ID", 
                        icon: Icons.memory, 
                        controller: _deviceIdController, 
                        validator: (v) => v!.isEmpty ? "Required" : null
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : GradientButton(text: "Pair Device", onPressed: _submitPairing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}