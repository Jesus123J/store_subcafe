import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/trabajador_dto.dart';

/// Lista de trabajadores (clientes con esTrabajador = true).
/// El backend ya filtra por esTrabajador en GET /clientes.
final trabajadoresProvider =
    FutureProvider.autoDispose<List<TrabajadorDto>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.clientes);
  return list
      .map((e) => TrabajadorDto.fromJson(e as Map<String, dynamic>))
      .where((t) => t.activo)
      .toList();
});
