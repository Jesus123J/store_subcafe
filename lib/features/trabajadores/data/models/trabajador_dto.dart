/// Trabajador del negocio (persistido como cliente con esTrabajador = true).
class TrabajadorDto {
  TrabajadorDto({
    required this.id,
    required this.dni,
    required this.nombres,
    required this.apellidos,
    required this.activo,
    this.telefono,
  });

  factory TrabajadorDto.fromJson(Map<String, dynamic> j) => TrabajadorDto(
        id: j['id'] as String,
        dni: j['dni'] as String,
        nombres: j['nombres'] as String,
        apellidos: j['apellidos'] as String,
        telefono: j['telefono'] as String?,
        activo: j['activo'] as bool? ?? true,
      );

  final String id;
  final String dni;
  final String nombres;
  final String apellidos;
  final String? telefono;
  final bool activo;

  String get nombreCompleto => '$nombres $apellidos';
}
