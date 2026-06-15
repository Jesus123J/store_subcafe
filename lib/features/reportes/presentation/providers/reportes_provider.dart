import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/reportes_models.dart';

/// Reporte agregado de ventas (ultimos 7 dias por defecto).
final ventasDiariasProvider =
    FutureProvider.autoDispose<VentasDiariasReporte>((ref) async {
  final json = await ApiClient.instance.getData<Map<String, dynamic>>(
    ApiEndpoints.reporteVentasDiarias,
  );
  return VentasDiariasReporte.fromJson(json);
});

/// Top productos (ultimos 30 dias por defecto).
final topProductosProvider =
    FutureProvider.autoDispose<List<TopProductoReporte>>((ref) async {
  final list = await ApiClient.instance.getData<List<dynamic>>(
    '${ApiEndpoints.reporteTopProductos}?limit=5',
  );
  return list
      .map((e) => TopProductoReporte.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Productos con stock por debajo del minimo.
final stockBajoProvider =
    FutureProvider.autoDispose<List<StockProductoReporte>>((ref) async {
  final list = await ApiClient.instance.getData<List<dynamic>>(
    ApiEndpoints.reporteStockBajo,
  );
  return list
      .map((e) => StockProductoReporte.fromJson(e as Map<String, dynamic>))
      .toList();
});
