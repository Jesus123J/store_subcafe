/// Fila de GET /api/deudores (vista v_deudores del backend).
class DeudorModel {
  DeudorModel({
    required this.clienteId,
    required this.dni,
    required this.nombreCompleto,
    required this.pendienteMes,
    required this.consumosMes,
    required this.deudaAcumulada,
    required this.deudaTotal,
    this.empleadoId,
    this.condicionLaboral,
    this.ultimoConsumo,
  });

  factory DeudorModel.fromJson(Map<String, dynamic> j) => DeudorModel(
        clienteId: j['cliente_id'] as String,
        dni: j['dni'] as String? ?? '',
        nombreCompleto: j['nombre_completo'] as String? ?? '—',
        empleadoId: (j['empleado_id'] as num?)?.toInt(),
        condicionLaboral: j['condicion_laboral'] as String?,
        pendienteMes: (j['pendiente_mes'] as num?)?.toDouble() ?? 0,
        consumosMes: (j['consumos_mes'] as num?)?.toInt() ?? 0,
        deudaAcumulada: (j['deuda_acumulada'] as num?)?.toDouble() ?? 0,
        deudaTotal: (j['deuda_total'] as num?)?.toDouble() ?? 0,
        ultimoConsumo: j['ultimo_consumo'] == null
            ? null
            : DateTime.tryParse(j['ultimo_consumo'] as String),
      );

  final String clienteId;
  final String dni;
  final String nombreCompleto;
  final int? empleadoId;
  final String? condicionLaboral;
  final double pendienteMes;
  final int consumosMes;
  final double deudaAcumulada;
  final double deudaTotal;
  final DateTime? ultimoConsumo;

  /// Está enlazado al padrón de FinantialTracker (employees).
  bool get enlazadoFinantial => empleadoId != null;
}

/// Movimiento (consumo a crédito) de un trabajador.
class DeudorMovimientoModel {
  DeudorMovimientoModel({
    required this.id,
    required this.monto,
    required this.fecha,
    required this.cerrado,
    this.ventaId,
    this.descripcion,
    this.registradoPor,
  });

  factory DeudorMovimientoModel.fromJson(Map<String, dynamic> j) =>
      DeudorMovimientoModel(
        id: j['id'] as String,
        ventaId: j['ventaId'] as String?,
        monto: (j['monto'] as num).toDouble(),
        descripcion: j['descripcion'] as String?,
        fecha: DateTime.parse(j['fecha'] as String),
        cerrado: j['cerrado'] as bool? ?? false,
        registradoPor: j['registradoPor'] as String?,
      );

  final String id;
  final String? ventaId;
  final double monto;
  final String? descripcion;
  final DateTime fecha;
  final bool cerrado;
  final String? registradoPor;

  bool get vieneDelPos => ventaId != null;
}
