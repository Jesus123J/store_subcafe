import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/compra_model.dart';

final comprasListProvider =
    FutureProvider.autoDispose<List<CompraModel>>((ref) async {
  final list = await ApiClient.instance.getData<List<dynamic>>(
    ApiEndpoints.compras,
  );
  return list
      .map((e) => CompraModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Detalle de una compra especifica (con items).
final compraDetalleProvider = FutureProvider.autoDispose
    .family<CompraModel, String>((ref, compraId) async {
  final json = await ApiClient.instance.getData<Map<String, dynamic>>(
    '${ApiEndpoints.compras}/$compraId',
  );
  return CompraModel.fromJson(json);
});

final comprasControllerProvider = Provider<ComprasController>(
  (ref) => ComprasController(ref),
);

class ComprasController {
  ComprasController(this._ref);
  final Ref _ref;

  Future<CompraModel> crear({
    required String proveedorId,
    String? nroDocumento,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.compras,
      body: {
        'proveedorId': proveedorId,
        if (nroDocumento != null && nroDocumento.isNotEmpty)
          'nroDocumento': nroDocumento,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
        'items': items,
      },
    );
    _ref.invalidate(comprasListProvider);
    return CompraModel.fromJson(json);
  }
}
