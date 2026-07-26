import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/envio_ft_model.dart';
import 'creditos_provider.dart';

/// Lista de envios a FinantialTracker (historial + estados).
final enviosFtProvider =
    FutureProvider.autoDispose<List<EnvioFtModel>>((ref) async {
  final list =
      await ApiClient.instance.getData<List<dynamic>>(ApiEndpoints.ftEnvios);
  return list
      .map((e) => EnvioFtModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Health check de la conexion a FT (para deshabilitar botones si esta caida).
final ftHealthProvider = FutureProvider.autoDispose<FtHealthDto>((ref) async {
  final json = await ApiClient.instance
      .getData<Map<String, dynamic>>(ApiEndpoints.ftHealth);
  return FtHealthDto(
    enabled: json['enabled'] as bool? ?? false,
    dbReachable: json['dbReachable'] as bool? ?? false,
  );
});

class FtHealthDto {
  const FtHealthDto({required this.enabled, required this.dbReachable});
  final bool enabled;
  final bool dbReachable;
  bool get ok => enabled && dbReachable;
}

/// Acciones sobre FT (enviar cierre/credito, revertir).
final ftControllerProvider =
    Provider<FinancialTrackerController>((ref) => FinancialTrackerController(ref));

class FinancialTrackerController {
  FinancialTrackerController(this._ref);
  final Ref _ref;

  Future<EnvioFtModel> enviarCierre(String cierreId) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.ftEnviarCierre(cierreId),
    );
    _invalidarTodo();
    return EnvioFtModel.fromJson(json);
  }

  Future<EnvioFtModel> enviarCredito(String creditoId) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.ftEnviarCredito(creditoId),
    );
    _invalidarTodo();
    return EnvioFtModel.fromJson(json);
  }

  Future<void> revertir(String envioId, String? motivo) async {
    await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.ftRevertir(envioId),
      body: {if (motivo != null && motivo.isNotEmpty) 'motivo': motivo},
    );
    _invalidarTodo();
  }

  void _invalidarTodo() {
    _ref.invalidate(enviosFtProvider);
    _ref.invalidate(creditosListProvider);
  }
}
