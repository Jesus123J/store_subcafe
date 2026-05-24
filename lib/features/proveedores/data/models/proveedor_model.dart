class ProveedorModel {
  ProveedorModel({
    required this.id,
    required this.razonSocial,
    required this.ruc,
    required this.activo,
    this.direccion,
    this.telefono,
  });

  factory ProveedorModel.fromJson(Map<String, dynamic> json) {
    return ProveedorModel(
      id: json['id'] as String,
      razonSocial: json['razonSocial'] as String,
      ruc: json['ruc'] as String,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  final String id;
  final String razonSocial;
  final String ruc;
  final String? direccion;
  final String? telefono;
  final bool activo;
}
