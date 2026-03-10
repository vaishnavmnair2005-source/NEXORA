import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required to fix orientation or status bar color
import 'utils/constants.dart';
import 'screens/splash_screen.dart';       // ✅ Start with the Splash Screen
import 'screens/offline_mode_service.dart'; // ✅ Offline connectivity monitoring

void main() {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. optional: Set Status Bar Color to Transparent for that "Full Screen" look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // 3. Start offline connectivity monitoring
  ConnectivityService().init();

  // 4. Run the App
  runApp(const NexoraApp());
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexora MediTwin',
      debugShowCheckedModeBanner: false, // Hides the "Debug" banner

      // --- GLOBAL THEME SETUP ---
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background, // Deep Black/Blue
        primaryColor: AppColors.primary, // Medical Cyan/Blue
        
        // standard app bar theme for all screens
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        
        // Standard text theme
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
        ),
        
        // Input decoration theme (TextFields)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
      ),

      // ✅ START HERE: The Splash Screen handles the "Auto-Login" logic
      home: const SplashScreen(),
    );
  }
}