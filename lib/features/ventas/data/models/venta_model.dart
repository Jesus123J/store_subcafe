/// Venta devuelta por el backend (GET/POST /api/ventas).
class VentaModel {
  VentaModel({
    required this.id,
    required this.cajaId,
    required this.usuarioNombre,
    required this.fecha,
    required this.total,
    required this.anulada,
    required this.tieneCredito,
    required this.items,
    required this.pagos,
    this.observacion,
    this.motivoAnulacion,
    this.clienteId,
    this.clienteNombre,
  });

  factory VentaModel.fromJson(Map<String, dynamic> j) => VentaModel(
        id: j['id'] as String,
        cajaId: j['cajaId'] as String? ?? '',
        usuarioNombre: j['usuarioNombre'] as String? ?? '',
        fecha: DateTime.parse(j['fecha'] as String),
        total: (j['total'] as num).toDouble(),
        anulada: j['anulada'] as bool? ?? false,
        tieneCredito: j['tieneCredito'] as bool? ?? false,
        observacion: j['observacion'] as String?,
        motivoAnulacion: j['motivoAnulacion'] as String?,
        clienteId: j['clienteId'] as String?,
        clienteNombre: j['clienteNombre'] as String?,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => VentaItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagos: (j['pagos'] as List<dynamic>? ?? [])
            .map((e) => VentaPagoModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String cajaId;
  final String usuarioNombre;
  final DateTime fecha;
  final double total;
  final bool anulada;
  final bool tieneCredito;
  final String? observacion;
  final String? motivoAnulacion;
  final String? clienteId;
  final String? clienteNombre;
  final List<VentaItemModel> items;
  final List<VentaPagoModel> pagos;

  int get cantidadItems => items.fold(0, (s, i) => s + i.cantidad.round());

  /// "Efectivo", "Yape + Crédito", "Mixto"
  String get formaPagoResumen {
    final labels = pagos.map((p) => p.formaPagoLabel).toList();
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]} + ${labels[1]}';
    return 'Mixto';
  }

  /// Código corto para mostrar / imprimir.
  String get codigo => 'V-${id.substring(0, 8).toUpperCase()}';
}

class VentaItemModel {
  VentaItemModel({
    required this.productoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.codigo,
  });

  factory VentaItemModel.fromJson(Map<String, dynamic> j) => VentaItemModel(
        productoId: j['productoId'] as String,
        codigo: j['codigo'] as String?,
        descripcion: j['descripcion'] as String? ?? '',
        cantidad: (j['cantidad'] as num).toDouble(),
        precioUnitario: (j['precioUnitario'] as num).toDouble(),
        subtotal: (j['subtotal'] as num).toDouble(),
      );

  final String productoId;
  final String? codigo;
  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;
}

class VentaPagoModel {
  VentaPagoModel({
    required this.formaPago,
    required this.monto,
    this.codigoOperacion,
    this.clienteId,
    this.clienteNombre,
  });

  factory VentaPagoModel.fromJson(Map<String, dynamic> j) => VentaPagoModel(
        formaPago: j['formaPago'] as String,
        monto: (j['monto'] as num).toDouble(),
        codigoOperacion: j['codigoOperacion'] as String?,
        clienteId: j['clienteId'] as String?,
        clienteNombre: j['clienteNombre'] as String?,
      );

  final String formaPago; // EFECTIVO | YAPE | PLIN | NIUBIZ | CREDITO
  final double monto;
  final String? codigoOperacion;
  final String? clienteId;
  final String? clienteNombre;

  String get formaPagoLabel => switch (formaPago) {
        'EFECTIVO' => 'Efectivo',
        'YAPE' => 'Yape',
        'PLIN' => 'Plin',
        'NIUBIZ' => 'Niubiz',
        'CREDITO' => 'Crédito',
        _ => formaPago,
      };
}
