import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/producto_model.dart';

abstract class ProductosDataSource {
  Future<List<ProductoModel>> listar();
}

class ProductosDataSourceImpl implements ProductosDataSource {
  ProductosDataSourceImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<ProductoModel>> listar() async {
    final list = await _api.getData<List<dynamic>>(ApiEndpoints.productos);
    return list
        .map((e) => ProductoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
