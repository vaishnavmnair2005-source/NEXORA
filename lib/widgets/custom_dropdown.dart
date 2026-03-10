import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;

  const CustomDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface, // Uses the dark slate from constants
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint, 
            style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5))
          ),
          dropdownColor: AppColors.surface, // Background of the popup list
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary), // Updated color name
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item, 
                style: const TextStyle(color: Colors.white) // White text for dark mode
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}