import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/deudor_model.dart';

/// Texto de búsqueda (DNI o nombre) de la pestaña Deudores.
final deudoresBusquedaProvider = StateProvider<String>((_) => '');

/// Trabajadores con deuda viva (mes en curso + acumulada).
final deudoresProvider =
    FutureProvider.autoDispose<List<DeudorModel>>((ref) async {
  final q = ref.watch(deudoresBusquedaProvider).trim();
  final list = await ApiClient.instance.getData<List<dynamic>>(
    ApiEndpoints.deudores,
    query: q.isEmpty ? null : {'q': q},
  );
  return list
      .map((e) => DeudorModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Totales generales.
final deudoresResumenProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ApiClient.instance
      .getData<Map<String, dynamic>>(ApiEndpoints.deudoresResumen);
});

/// Estado de cuenta de un trabajador (movimientos + cierres + abonos FT).
final deudorDetalleProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, clienteId) async {
  return ApiClient.instance
      .getData<Map<String, dynamic>>(ApiEndpoints.deudorDetalle(clienteId));
});

void refrescarDeudores(WidgetRef ref) {
  ref.invalidate(deudoresProvider);
  ref.invalidate(deudoresResumenProvider);
}
