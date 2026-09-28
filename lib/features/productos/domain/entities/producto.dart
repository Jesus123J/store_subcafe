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
    this.precioVenta = 0,
    this.costo = 0,
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

  /// Precio de venta vigente (último producto_precios). Lo entrega GET /productos.
  final double precioVenta;
  final double costo;

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
        precioVenta,
        costo,
      ];
}
