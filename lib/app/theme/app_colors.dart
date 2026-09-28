import 'package:flutter/material.dart';

/// Paleta de Sub Café (cafetería, bodega y fotocopiadora del Hospital San José).
///
/// La identidad sale del propio local: el café tostado manda, el papel del
/// ticket térmico es el fondo, y los colores de estado son los de la caja:
/// verde para lo cobrado, ámbar para lo fiado, rojo para lo anulado.
class AppColors {
  AppColors._();

  // ─── Marca ───
  /// Café tostado: barra lateral, títulos, acciones principales.
  static const Color primary = Color(0xFF3F2A1D);

  /// Café con leche: degradados y estados de la marca.
  static const Color primaryLight = Color(0xFF7A5238);

  /// Espuma: relleno suave para chips y resaltados de marca.
  static const Color primarySoft = Color(0xFFF1E9E0);

  // ─── Superficies ───
  /// Papel de ticket: fondo general, neutro y cálido sin ser crema.
  static const Color background = Color(0xFFF4F2EE);
  static const Color surface = Colors.white;

  /// Kraft claro: bordes y divisores.
  static const Color border = Color(0xFFE3DCD2);

  // ─── Estados (los de la caja) ───
  /// Cobrado / correcto.
  static const Color secondary = Color(0xFF2E7D5B);

  /// Fiado / crédito / atención.
  static const Color warning = Color(0xFFB7791F);

  /// Anulado / error.
  static const Color error = Color(0xFFB42318);

  /// Informativo.
  static const Color info = Color(0xFF2B6CB0);

  // ─── Texto ───
  /// Tinta.
  static const Color textPrimary = Color(0xFF211C18);

  /// Tinta desvaída (secundarios, ayudas).
  static const Color textSecondary = Color(0xFF6F675E);
}
