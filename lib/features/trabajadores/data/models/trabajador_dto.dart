/// Trabajador que viene passthrough desde FinantialTracker.employees.
/// La bodega NO tiene tabla local de trabajadores — cada vez que se
/// necesitan se piden a FT en vivo via GET /trabajadores.
///
/// El backend excluye a los admins/bajas (user.state='9' o rol admin),
/// por eso lo que llega aca ya esta listo para pintarse como opciones
/// validas para credito.
class TrabajadorDto {
  const TrabajadorDto({
    required this.dni,
    required this.nombreCompleto,
    this.employeeIdFt,
    this.estadoEmpleo,
    this.codigoEstado,
  });

  factory TrabajadorDto.fromJson(Map<String, dynamic> j) => TrabajadorDto(
        dni: j['dni'] as String,
        nombreCompleto: (j['nombre_completo'] as String?) ??
            (j['nombreCompleto'] as String?) ??
            '',
        employeeIdFt: (j['id'] as num?)?.toInt(),
        estadoEmpleo: j['estado_empleo'] as String?,
        codigoEstado: j['codigo_estado'] as String?,
      );

  /// DNI (llave que compartimos con FT para vincular creditos).
  final String dni;

  /// Nombre completo tal como esta cargado en la planilla.
  final String nombreCompleto;

  /// employee_id nativo del FT (int). Util cuando pusheamos abonos:
  /// el AbonoDao del FT recibe employee_id, no DNI.
  final int? employeeIdFt;

  /// Texto libre del estado ("Nombrado", "CAS", "Cese", etc.).
  final String? estadoEmpleo;

  /// Codigo tabulado del estado (para colorear consistentemente).
  final String? codigoEstado;
}
