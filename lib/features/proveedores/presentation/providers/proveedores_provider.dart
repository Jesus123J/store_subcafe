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
