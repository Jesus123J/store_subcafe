import '../../domain/entities/producto.dart';

class ProductoModel extends Producto {
  const ProductoModel({
    required super.id,
    required super.descripcion,
    required super.stock,
    required super.stockMinimo,
    required super.esServicio,
    required super.usaContometro,
    required super.activo,
    super.codigo,
  });

  factory ProductoModel.fromJson(Map<String, dynamic> json) {
    return ProductoModel(
      id: json['id'] as String,
      codigo: json['codigo'] as String?,
      descripcion: json['descripcion'] as String,
      stock: (json['stock'] as num).toDouble(),
      stockMinimo: (json['stockMinimo'] as num).toDouble(),
      esServicio: json['esServicio'] as bool? ?? false,
      usaContometro: json['usaContometro'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
    );
  }
}
