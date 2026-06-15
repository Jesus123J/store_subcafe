class CompraModel {
  CompraModel({
    required this.id,
    required this.proveedor,
    required this.fecha,
    required this.total,
    this.nroDocumento,
    this.observaciones,
    this.items,
  });

  /// Acepta el JSON tanto en formato viejo (proveedor: {razonSocial})
  /// como en el nuevo (proveedorRazonSocial directo).
  factory CompraModel.fromJson(Map<String, dynamic> json) {
    String proveedor;
    if (json['proveedorRazonSocial'] != null) {
      proveedor = json['proveedorRazonSocial'] as String;
    } else {
      final p = json['proveedor'] as Map<String, dynamic>?;
      proveedor = p?['razonSocial'] as String? ?? 'Sin proveedor';
    }
    return CompraModel(
      id: json['id'] as String,
      proveedor: proveedor,
      fecha: DateTime.parse(json['fecha'] as String),
      total: (json['total'] as num).toDouble(),
      nroDocumento: json['nroDocumento'] as String?,
      observaciones: json['observaciones'] as String?,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => CompraItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String proveedor;
  final DateTime fecha;
  final double total;
  final String? nroDocumento;
  final String? observaciones;
  final List<CompraItemModel>? items;
}

class CompraItemModel {
  CompraItemModel({
    required this.id,
    required this.productoId,
    required this.productoDescripcion,
    required this.cantidad,
    required this.costoUnitario,
    required this.subtotal,
  });

  factory CompraItemModel.fromJson(Map<String, dynamic> j) {
    return CompraItemModel(
      id: j['id'] as String,
      productoId: j['productoId'] as String,
      productoDescripcion: j['productoDescripcion'] as String,
      cantidad: (j['cantidad'] as num).toDouble(),
      costoUnitario: (j['costoUnitario'] as num).toDouble(),
      subtotal: (j['subtotal'] as num).toDouble(),
    );
  }

  final String id;
  final String productoId;
  final String productoDescripcion;
  final double cantidad;
  final double costoUnitario;
  final double subtotal;
}
