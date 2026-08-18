import 'package:flutter/material.dart';

class AppColors {
  // Main Theme Colors (Summer Light)
  static const Color background = Color(0xFFFDFBF7); // light-0
  static const Color surface = Color(0xFFF4F1EA); // light-1
  static const Color surfaceAlt = Color(0xFFEBE5DC); // light-2
  
  static const Color textMain = Color(0xFF2C3240);
  static const Color textMuted = Color(0xFF5A6679);

  // Brand Colors
  static const Color primary = Color(0xFF0D7377);
  static const Color primaryLight = Color(0xFF14A8AE);
  
  static const Color gold = Color(0xFFF4A535);
  static const Color goldDark = Color(0xFFC87D0E);
  
  static const Color coral = Color(0xFFE8604C);
  
  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
