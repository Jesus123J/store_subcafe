import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/datasources/productos_datasource.dart';
import '../../data/models/producto_model.dart';

final productosDataSourceProvider = Provider<ProductosDataSource>(
  (ref) => ProductosDataSourceImpl(ApiClient.instance),
);

final productosListProvider =
    FutureProvider.autoDispose<List<ProductoModel>>((ref) {
  return ref.watch(productosDataSourceProvider).listar();
});
