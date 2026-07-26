import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/trabajador_dto.dart';

/// Lista de trabajadores passthrough desde FinantialTracker.
/// Sin conexion a FT -> este provider lanza excepcion, que la UI captura.
final trabajadoresProvider =
    FutureProvider.autoDispose<List<TrabajadorDto>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.trabajadores);
  return list
      .map((e) => TrabajadorDto.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Mapa DNI -> nombre para resolver rapido nombres en pantallas que
/// muestran DNIs (creditos del mes, deuda acumulada). Cachea el
/// resultado del provider anterior.
final trabajadoresPorDniProvider =
    Provider.autoDispose<Map<String, String>>((ref) {
  final list = ref.watch(trabajadoresProvider).valueOrNull;
  if (list == null) return const {};
  return {for (final t in list) t.dni: t.nombreCompleto};
});
