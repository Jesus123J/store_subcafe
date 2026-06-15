import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/credito_model.dart';

/// Lista de TODOS los creditos (no agregados).
final creditosListProvider =
    FutureProvider.autoDispose<List<CreditoModel>>((ref) async {
  final list = await ApiClient.instance.getData<List<dynamic>>(
    ApiEndpoints.creditos,
  );
  return list
      .map((e) => CreditoModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Agrega los creditos por trabajador para mostrar deuda total.
/// Solo cuenta los NO cerrados (pendientes).
final deudaPorTrabajadorProvider =
    Provider.autoDispose<AsyncValue<List<DeudaPorTrabajador>>>((ref) {
  return ref.watch(creditosListProvider).whenData((creditos) {
    final pendientes = creditos.where((c) => !c.cerrado).toList();
    final mapa = <String, List<CreditoModel>>{};
    for (final c in pendientes) {
      mapa.putIfAbsent(c.trabajadorId, () => []).add(c);
    }
    return mapa.entries.map((e) {
      final lista = e.value;
      lista.sort((a, b) => b.fecha.compareTo(a.fecha));
      return DeudaPorTrabajador(
        trabajadorId: e.key,
        trabajadorNombre: lista.first.trabajadorNombre,
        deudaTotal: lista.fold<double>(0, (s, c) => s + c.monto),
        consumos: lista.length,
        ultimoConsumo: lista.first.fecha,
      );
    }).toList()
      ..sort((a, b) => b.deudaTotal.compareTo(a.deudaTotal));
  });
});
