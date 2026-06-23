import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/models/proveedor_model.dart';

final proveedoresListProvider =
    FutureProvider.autoDispose<List<ProveedorModel>>((ref) async {
  final list = await ApiClient.instance.getData<List<dynamic>>(
    ApiEndpoints.proveedores,
  );
  return list
      .map((e) => ProveedorModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final proveedoresControllerProvider = Provider<ProveedoresController>(
  (ref) => ProveedoresController(ref),
);

class ProveedoresController {
  ProveedoresController(this._ref);
  final Ref _ref;

  Future<ProveedorModel> crear({
    required String razonSocial,
    required String ruc,
    String? direccion,
    String? telefono,
  }) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.proveedores,
      body: {
        'razonSocial': razonSocial.trim(),
        'ruc': ruc.trim(),
        if (direccion != null && direccion.trim().isNotEmpty)
          'direccion': direccion.trim(),
        if (telefono != null && telefono.trim().isNotEmpty)
          'telefono': telefono.trim(),
      },
    );
    _ref.invalidate(proveedoresListProvider);
    return ProveedorModel.fromJson(json);
  }

  Future<void> desactivar(String id) async {
    await ApiClient.instance.deleteData('${ApiEndpoints.proveedores}/$id');
    _ref.invalidate(proveedoresListProvider);
  }
}
