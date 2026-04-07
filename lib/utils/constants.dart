import 'package:flutter/material.dart';

// --- API Configuration ---
class ApiConstants {
  // 🛑 UPDATE THIS LINE with your current Wi-Fi IPv4 address!
  //static const String baseUrl = "http://192.168.0.101:8000"; 
  
  // Keep these here so you can easily switch them by commenting/uncommenting:
  //static const String baseUrl = "http://10.22.203.142:8000"; // College IP Vaishnav 
  //static const String baseUrl = "http://10.190.202.142:8000"; // College IP Vaishali
  static const String baseUrl = "http://192.168.0.101:8000"; //Home IP
  // static const String baseUrl = "http://10.0.2.2:8000";     // Android Emulator IP
}

class AppColors {
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color faceCard = Color(0xFF0D47A1);   // Deep Blue
  static const Color primary = Color(0xFF00E5FF);    // Electric Cyan
  static const Color surface = Color(0xFF121212);    
  
  static const Color textPrimary = Colors.white; 
  static const Color textSecondary = Colors.white70;
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF32D74B);

  static const List<Color> primaryGradient = [
    Color(0xFF0D47A1),
    Color(0xFF00E5FF),
  ];
}

class AppTextStyles {
  static const TextStyle brandMain = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: 2.0,
  );

  static const TextStyle brandSub = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: AppColors.primary,
    letterSpacing: 4.0,
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 1.2,
  );
}