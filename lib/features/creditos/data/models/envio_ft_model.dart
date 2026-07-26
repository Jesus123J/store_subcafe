/// Envio a FinantialTracker: un lote de deuda mensual (o credito individual)
/// que se pusheo a la BD de planilla del HSJ.
class EnvioFtModel {
  const EnvioFtModel({
    required this.id,
    required this.loteIdFt,
    required this.trabajadoresEnviados,
    required this.montoTotal,
    required this.fecha,
    required this.estado,
    this.cierreId,
    this.creditoId,
    this.motivoReversion,
    this.fechaReversion,
    this.dnisNoEncontrados = const [],
  });

  factory EnvioFtModel.fromJson(Map<String, dynamic> j) => EnvioFtModel(
        id: j['id'] as String,
        cierreId: j['cierreId'] as String?,
        creditoId: j['creditoId'] as String?,
        loteIdFt: (j['loteIdFt'] as num).toInt(),
        trabajadoresEnviados: (j['trabajadoresEnviados'] as num).toInt(),
        montoTotal: (j['montoTotal'] as num).toDouble(),
        fecha: DateTime.parse(j['fecha'] as String),
        estado: j['estado'] as String? ?? 'ACTIVO',
        motivoReversion: j['motivoReversion'] as String?,
        fechaReversion: j['fechaReversion'] != null
            ? DateTime.parse(j['fechaReversion'] as String)
            : null,
        dnisNoEncontrados: (j['dnisNoEncontrados'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );

  final String id;
  final String? cierreId;
  final String? creditoId;
  final int loteIdFt;
  final int trabajadoresEnviados;
  final double montoTotal;
  final DateTime fecha;
  final String estado; // 'ACTIVO' | 'REVERTIDO'
  final String? motivoReversion;
  final DateTime? fechaReversion;
  final List<String> dnisNoEncontrados;

  bool get activo => estado == 'ACTIVO';
}
