import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../data/datasources/productos_datasource.dart';
import '../../data/models/producto_model.dart';

final productosDataSourceProvider = Provider<ProductosDataSource>(
  (ref) => ProductosDataSourceImpl(ApiClient.instance),
);

final productosListProvider =
    FutureProvider.autoDispose<List<ProductoModel>>((ref) {
  return ref.watch(productosDataSourceProvider).listar();
});

final productosControllerProvider = Provider<ProductosController>(
  (ref) => ProductosController(ref),
);

class ProductosController {
  ProductosController(this._ref);
  final Ref _ref;

  Future<ProductoModel> crear({
    String? codigo,
    required String descripcion,
    required double stockInicial,
    required double stockMinimo,
    required double costo,
    required double precioVenta,
    required bool esServicio,
    required bool usaContometro,
    required bool esBazar,
  }) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.productos,
      body: {
        if (codigo != null && codigo.trim().isNotEmpty) 'codigo': codigo.trim(),
        'descripcion': descripcion.trim(),
        'stockInicial': stockInicial,
        'stockMinimo': stockMinimo,
        'costo': costo,
        'precioVenta': precioVenta,
        'esServicio': esServicio,
        'usaContometro': usaContometro,
        'esBazar': esBazar,
      },
    );
    _ref.invalidate(productosListProvider);
    return ProductoModel.fromJson(json);
  }

  Future<void> desactivar(String id) async {
    await ApiClient.instance.deleteData('${ApiEndpoints.productos}/$id');
    _ref.invalidate(productosListProvider);
  }
}
