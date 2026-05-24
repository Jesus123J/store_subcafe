import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const base = AppColors.textPrimary;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: base,
        onSurfaceVariant: base,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // ── Texto: todo en oscuro ──
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: base),
        displayMedium: TextStyle(color: base),
        displaySmall: TextStyle(color: base),
        headlineLarge: TextStyle(color: base, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: base, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: base, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: base, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: base, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: base, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: base),
        bodyMedium: TextStyle(color: base),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        labelLarge: TextStyle(color: base, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: base),
        labelSmall: TextStyle(color: base),
      ),
      iconTheme: const IconThemeData(color: base),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ── DataTable: encabezados y celdas en oscuro ──
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        dataTextStyle: TextStyle(
          color: base,
          fontSize: 13,
        ),
        dividerThickness: 0.6,
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 0.6),
      listTileTheme: const ListTileThemeData(
        textColor: base,
        iconColor: base,
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
      );
}
