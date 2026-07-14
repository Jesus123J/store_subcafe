/// Trabajador que viene passthrough desde FinantialTracker.employees.
/// Solo transportamos DNI + nombre — la bodega NO tiene tabla local
/// de trabajadores; cada vez que se necesitan se piden a FT en vivo.
class TrabajadorDto {
  const TrabajadorDto({
    required this.dni,
    required this.nombreCompleto,
  });

  factory TrabajadorDto.fromJson(Map<String, dynamic> j) => TrabajadorDto(
        dni: j['dni'] as String,
        nombreCompleto: (j['nombre_completo'] as String?) ??
            (j['nombreCompleto'] as String?) ??
            '',
      );

  final String dni;
  final String nombreCompleto;
}
