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
