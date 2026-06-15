import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../data/models/caja_models.dart';

/// Caja abierta del usuario en sesion (o null si no tiene ninguna).
final cajaAbiertaProvider =
    FutureProvider.autoDispose<CajaDetalleDto?>((ref) async {
  try {
    final json = await ApiClient.instance.getData<Map<String, dynamic>>(
      ApiEndpoints.cajaAbierta,
    );
    return CajaDetalleDto.fromJson(json);
  } on ApiException catch (e) {
    if (e.isNotFound) return null; // sin caja abierta
    rethrow;
  }
});

/// Acciones sobre cajas (abrir, cerrar, registrar avance).
final cajasControllerProvider = Provider<CajasController>((ref) {
  return CajasController(ref);
});

class CajasController {
  CajasController(this._ref);
  final Ref _ref;

  Future<void> abrir({
    required String turno,         // 'DIA' o 'NOCHE'
    required double montoApertura,
    int? contometroInicio,
  }) async {
    await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.abrirCaja,
      body: {
        'turno': turno,
        'montoApertura': montoApertura,
        if (contometroInicio != null) 'contometroInicio': contometroInicio,
      },
    );
    _ref.invalidate(cajaAbiertaProvider);
  }

  Future<void> cerrar({
    required String cajaId,
    required double montoCierre,
    int? contometroFin,
  }) async {
    await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.cerrarCaja(cajaId),
      body: {
        'montoCierre': montoCierre,
        if (contometroFin != null) 'contometroFin': contometroFin,
      },
    );
    _ref.invalidate(cajaAbiertaProvider);
  }

  Future<void> registrarAvance({
    required String cajaId,
    required double monto,
    String? observacion,
  }) async {
    await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.avanceCaja(cajaId),
      body: {
        'monto': monto,
        if (observacion != null && observacion.isNotEmpty)
          'observacion': observacion,
      },
    );
    _ref.invalidate(cajaAbiertaProvider);
  }
}
