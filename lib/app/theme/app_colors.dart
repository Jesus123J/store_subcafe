import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1A365D);
  static const Color primaryLight = Color(0xFF2C5282);
  static const Color secondary = Color(0xFF38A169);
  static const Color background = Color(0xFFF7FAFC);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFC53030);
  static const Color warning = Color(0xFFD69E2E);
  static const Color info = Color(0xFF3182CE);

  static const Color textPrimary = Color(0xFF2C3E50);
  // textSecondary subido de Slate-500 (#718096) a Slate-700 (#4A5568)
  // para mejorar contraste WCAG sobre fondo blanco / background claro.
  static const Color textSecondary = Color(0xFF4A5568);
  // Gris aun mas tenue para hints/placeholders que no compiten con contenido.
  static const Color textHint = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
}
