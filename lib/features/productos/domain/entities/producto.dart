import 'package:equatable/equatable.dart';

class Producto extends Equatable {
  const Producto({
    required this.id,
    required this.descripcion,
    required this.stock,
    required this.stockMinimo,
    required this.esServicio,
    required this.usaContometro,
    required this.activo,
    this.codigo,
    this.esBazar = false,
  });

  final String id;
  final String? codigo;
  final String descripcion;
  final double stock;
  final double stockMinimo;
  final bool esServicio;
  final bool usaContometro;
  final bool activo;

  /// Producto del bazar: aceptable como canje de vales y/o puntos.
  /// Definido por Karina en su respuesta del 17/jun/2026.
  final bool esBazar;

  bool get stockBajo => stock <= stockMinimo;

  @override
  List<Object?> get props => [
        id,
        codigo,
        descripcion,
        stock,
        stockMinimo,
        esServicio,
        usaContometro,
        activo,
        esBazar,
      ];
}
