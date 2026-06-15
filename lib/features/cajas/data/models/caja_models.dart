// Modelos de respuesta del backend para el modulo de cajas.

enum TipoTurno { dia, noche }
enum EstadoCaja { abierta, cerrada }

TipoTurno _parseTurno(String s) =>
    s.toUpperCase() == 'NOCHE' ? TipoTurno.noche : TipoTurno.dia;

EstadoCaja _parseEstado(String s) =>
    s.toUpperCase() == 'CERRADA' ? EstadoCaja.cerrada : EstadoCaja.abierta;

class CajaDto {
  CajaDto({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.turno,
    required this.estado,
    required this.fechaApertura,
    required this.montoApertura,
    this.fechaCierre,
    this.montoCierre,
    this.contometroInicio,
    this.contometroFin,
  });

  factory CajaDto.fromJson(Map<String, dynamic> j) {
    return CajaDto(
      id: j['id'] as String,
      usuarioId: j['usuarioId'] as String,
      usuarioNombre: j['usuarioNombre'] as String,
      turno: _parseTurno(j['turno'] as String),
      estado: _parseEstado(j['estado'] as String),
      fechaApertura: DateTime.parse(j['fechaApertura'] as String),
      fechaCierre: j['fechaCierre'] != null
          ? DateTime.parse(j['fechaCierre'] as String)
          : null,
      montoApertura: (j['montoApertura'] as num).toDouble(),
      montoCierre: (j['montoCierre'] as num?)?.toDouble(),
      contometroInicio: j['contometroInicio'] as int?,
      contometroFin: j['contometroFin'] as int?,
    );
  }

  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final TipoTurno turno;
  final EstadoCaja estado;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final double montoApertura;
  final double? montoCierre;
  final int? contometroInicio;
  final int? contometroFin;
}

class AvanceDto {
  AvanceDto({
    required this.id,
    required this.monto,
    required this.fecha,
    this.observacion,
  });

  factory AvanceDto.fromJson(Map<String, dynamic> j) {
    return AvanceDto(
      id: j['id'] as String,
      monto: (j['monto'] as num).toDouble(),
      observacion: j['observacion'] as String?,
      fecha: DateTime.parse(j['fecha'] as String),
    );
  }

  final String id;
  final double monto;
  final String? observacion;
  final DateTime fecha;
}

class CajaDetalleDto {
  CajaDetalleDto({
    required this.caja,
    required this.totalVentas,
    required this.ventasPorFormaPago,
    required this.avances,
    required this.totalAvances,
    required this.efectivoEsperadoEnCaja,
  });

  factory CajaDetalleDto.fromJson(Map<String, dynamic> j) {
    final mapVentas = (j['ventasPorFormaPago'] as Map<String, dynamic>?) ?? {};
    return CajaDetalleDto(
      caja: CajaDto.fromJson(j['caja'] as Map<String, dynamic>),
      totalVentas: (j['totalVentas'] as num).toDouble(),
      ventasPorFormaPago: mapVentas.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      avances: (j['avances'] as List<dynamic>)
          .map((a) => AvanceDto.fromJson(a as Map<String, dynamic>))
          .toList(),
      totalAvances: (j['totalAvances'] as num).toDouble(),
      efectivoEsperadoEnCaja: (j['efectivoEsperadoEnCaja'] as num).toDouble(),
    );
  }

  final CajaDto caja;
  final double totalVentas;
  final Map<String, double> ventasPorFormaPago;
  final List<AvanceDto> avances;
  final double totalAvances;
  final double efectivoEsperadoEnCaja;
}
