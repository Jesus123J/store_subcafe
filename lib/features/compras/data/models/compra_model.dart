class CompraModel {
  CompraModel({
    required this.id,
    required this.proveedor,
    required this.fecha,
    required this.total,
    this.nroDocumento,
    this.observaciones,
  });

  factory CompraModel.fromJson(Map<String, dynamic> json) {
    final proveedor = json['proveedor'] as Map<String, dynamic>?;
    return CompraModel(
      id: json['id'] as String,
      proveedor: proveedor?['razonSocial'] as String? ?? 'Sin proveedor',
      fecha: DateTime.parse(json['fecha'] as String),
      total: (json['total'] as num).toDouble(),
      nroDocumento: json['nroDocumento'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  final String id;
  final String proveedor;
  final DateTime fecha;
  final double total;
  final String? nroDocumento;
  final String? observaciones;
}
