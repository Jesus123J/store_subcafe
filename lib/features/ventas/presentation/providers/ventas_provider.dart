import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/venta_model.dart';
import '../widgets/multiple_pagos_dialog.dart';

/// Ventas de una caja (historial del turno). `null` = todas.
final ventasDeCajaProvider = FutureProvider.autoDispose
    .family<List<VentaModel>, String?>((ref, cajaId) async {
  final list = await ApiClient.instance.getData<List<dynamic>>(
    ApiEndpoints.ventas,
    query: cajaId == null ? null : {'cajaId': cajaId},
  );
  return list
      .map((e) => VentaModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Item del carrito tal como lo espera POST /api/ventas.
class VentaItemInput {
  VentaItemInput({required this.productoId, required this.cantidad});
  final String productoId;
  final double cantidad;

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'cantidad': cantidad,
      };
}

final ventasControllerProvider =
    Provider<VentasController>((ref) => VentasController(ref));

class VentasController {
  VentasController(this._ref);
  final Ref _ref;

  /// Registra la venta en el backend. Descuenta stock y, si hay pagos a
  /// CRÉDITO, anota la deuda del trabajador (visible en Deudores).
  Future<VentaModel> crear({
    required List<VentaItemInput> items,
    required List<PagoParcial> pagos,
    String? observacion,
  }) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.ventas,
      body: {
        'items': items.map((i) => i.toJson()).toList(),
        'pagos': pagos.map((p) => p.toJson()).toList(),
        if (observacion != null && observacion.isNotEmpty)
          'observacion': observacion,
      },
    );
    _ref.invalidate(ventasDeCajaProvider);
    return VentaModel.fromJson(json);
  }

  Future<VentaModel> anular(String ventaId, String motivo) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.anularVenta(ventaId),
      body: {'motivo': motivo},
    );
    _ref.invalidate(ventasDeCajaProvider);
    return VentaModel.fromJson(json);
  }
}
