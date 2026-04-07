import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key});
  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  bool isPrimary = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text("Caregiver Info", style: AppTextStyles.heading1),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: AppColors.faceCard, borderRadius: BorderRadius.circular(28)),
                  child: Column(
                    children: [
                      CustomTextField(hint: "Full Name", icon: Icons.person_add, controller: _name, validator: (v) => v!.isEmpty ? "Required" : null),
                      const SizedBox(height: 16),
                      CustomTextField(hint: "Relation", icon: Icons.family_restroom, controller: _relation, validator: (v) => v!.isEmpty ? "Required" : null),
                      const SizedBox(height: 16),
                      CustomTextField(hint: "Phone Number", icon: Icons.phone, controller: _phone, validator: (v) => v!.length == 10 ? null : "Enter 10 digits"),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text("Primary Caregiver?", style: TextStyle(color: Colors.white70)),
                          Radio<bool>(value: true, groupValue: isPrimary, onChanged: (v) => setState(() => isPrimary = v!)),
                          const Text("Yes", style: TextStyle(color: Colors.white)),
                          Radio<bool>(value: false, groupValue: isPrimary, onChanged: (v) => setState(() => isPrimary = v!)),
                          const Text("No", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                GradientButton(text: "Finish & Sync", onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Logic to send to FastAPI for insertion into all 5 tables
                  }
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}