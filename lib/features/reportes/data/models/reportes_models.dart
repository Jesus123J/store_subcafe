/// Modelos para el dashboard de Reportes.

class SerieDiariaPunto {
  SerieDiariaPunto({required this.fecha, required this.total});

  factory SerieDiariaPunto.fromJson(Map<String, dynamic> j) {
    return SerieDiariaPunto(
      fecha: DateTime.parse(j['fecha'] as String),
      total: (j['total'] as num).toDouble(),
    );
  }

  final DateTime fecha;
  final double total;
}

class VentasDiariasReporte {
  VentasDiariasReporte({
    required this.desde,
    required this.hasta,
    required this.totalGeneral,
    required this.cantidadTransacciones,
    required this.ticketPromedio,
    required this.porFormaPago,
    required this.porTurno,
    required this.serieDiaria,
  });

  factory VentasDiariasReporte.fromJson(Map<String, dynamic> j) {
    final formas = (j['porFormaPago'] as Map<String, dynamic>?) ?? {};
    final turnos = (j['porTurno'] as Map<String, dynamic>?) ?? {};
    return VentasDiariasReporte(
      desde: DateTime.parse(j['desde'] as String),
      hasta: DateTime.parse(j['hasta'] as String),
      totalGeneral: (j['totalGeneral'] as num).toDouble(),
      cantidadTransacciones: (j['cantidadTransacciones'] as num).toInt(),
      ticketPromedio: (j['ticketPromedio'] as num).toDouble(),
      porFormaPago:
          formas.map((k, v) => MapEntry(k, (v as num).toDouble())),
      porTurno: turnos.map((k, v) => MapEntry(k, (v as num).toDouble())),
      serieDiaria: (j['serieDiaria'] as List<dynamic>)
          .map((e) => SerieDiariaPunto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final DateTime desde;
  final DateTime hasta;
  final double totalGeneral;
  final int cantidadTransacciones;
  final double ticketPromedio;
  final Map<String, double> porFormaPago;
  final Map<String, double> porTurno;
  final List<SerieDiariaPunto> serieDiaria;
}

class StockProductoReporte {
  StockProductoReporte({
    required this.id,
    required this.descripcion,
    required this.stock,
    required this.stockMinimo,
    required this.bajoMinimo,
    this.codigo,
    this.costo,
    this.precioVenta,
    this.valoracion,
  });

  factory StockProductoReporte.fromJson(Map<String, dynamic> j) {
    return StockProductoReporte(
      id: j['id'] as String,
      codigo: j['codigo'] as String?,
      descripcion: j['descripcion'] as String,
      stock: (j['stock'] as num).toDouble(),
      stockMinimo: (j['stockMinimo'] as num).toDouble(),
      costo: (j['costo'] as num?)?.toDouble(),
      precioVenta: (j['precioVenta'] as num?)?.toDouble(),
      valoracion: (j['valoracion'] as num?)?.toDouble(),
      bajoMinimo: j['bajoMinimo'] as bool? ?? false,
    );
  }

  final String id;
  final String? codigo;
  final String descripcion;
  final double stock;
  final double stockMinimo;
  final double? costo;
  final double? precioVenta;
  final double? valoracion;
  final bool bajoMinimo;
}

class TopProductoReporte {
  TopProductoReporte({
    required this.productoId,
    required this.descripcion,
    required this.cantidadVendida,
    required this.totalFacturado,
  });

  factory TopProductoReporte.fromJson(Map<String, dynamic> j) {
    return TopProductoReporte(
      productoId: j['productoId'] as String,
      descripcion: j['descripcion'] as String,
      cantidadVendida: (j['cantidadVendida'] as num).toDouble(),
      totalFacturado: (j['totalFacturado'] as num).toDouble(),
    );
  }

  final String productoId;
  final String descripcion;
  final double cantidadVendida;
  final double totalFacturado;
}
