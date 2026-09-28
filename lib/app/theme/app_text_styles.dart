import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tipografías de Sub Café.
///
/// - Display: Fraunces, una serif con carácter de pizarra de cafetería.
///   Se usa con moderación: marca, títulos de pantalla y cifras grandes.
/// - Texto: Manrope, limpia y legible en pantallas de caja.
/// - Datos: IBM Plex Mono para montos, códigos y tickets, como una impresora térmica.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display(
          {double size = 24, Color color = AppColors.primary}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.3,
        height: 1.15,
      );

  static TextStyle mono({
    double size = 14,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);

  static TextStyle get h1 => display(size: 32);
  static TextStyle get h2 => display(size: 24);
  static TextStyle get h3 => display(size: 18);

  static TextStyle get body =>
      GoogleFonts.manrope(fontSize: 14, color: AppColors.textPrimary);

  static TextStyle get bodySmall =>
      GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary);

  static TextStyle get button =>
      GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700);
}
