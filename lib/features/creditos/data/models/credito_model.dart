/// Modelo de un credito a trabajador retornado por GET /api/creditos.
class CreditoModel {
  CreditoModel({
    required this.id,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.monto,
    required this.fecha,
    required this.cerrado,
  });

  factory CreditoModel.fromJson(Map<String, dynamic> json) {
    final trabajador = json['trabajador'] as Map<String, dynamic>?;
    return CreditoModel(
      id: json['id'] as String,
      trabajadorId: trabajador?['id'] as String? ?? '',
      trabajadorNombre:
          (trabajador?['nombreCompleto'] as String?) ?? 'Sin nombre',
      monto: (json['monto'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      cerrado: json['cerrado'] as bool? ?? false,
    );
  }

  final String id;
  final String trabajadorId;
  final String trabajadorNombre;
  final double monto;
  final DateTime fecha;
  final bool cerrado;
}

/// Resumen de deuda agregada por trabajador.
class DeudaPorTrabajador {
  DeudaPorTrabajador({
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.deudaTotal,
    required this.consumos,
    this.ultimoConsumo,
  });

  final String trabajadorId;
  final String trabajadorNombre;
  final double deudaTotal;
  final int consumos;
  final DateTime? ultimoConsumo;
}
