import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../auth/data/models/usuario_model.dart';
import '../../../auth/domain/entities/usuario.dart';

abstract class UsuariosDataSource {
  Future<List<UsuarioModel>> listar();
  Future<UsuarioModel> crear({
    required String username,
    required String password,
    required String nombreCompleto,
    required RolUsuario rol,
  });
  Future<UsuarioModel> actualizar({
    required String id,
    required String nombreCompleto,
    required RolUsuario rol,
    required bool activo,
  });
  Future<void> eliminar(String id);
}

class UsuariosDataSourceImpl implements UsuariosDataSource {
  UsuariosDataSourceImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<UsuarioModel>> listar() async {
    final list = await _api.getData<List<dynamic>>(ApiEndpoints.usuarios);
    return list
        .map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UsuarioModel> crear({
    required String username,
    required String password,
    required String nombreCompleto,
    required RolUsuario rol,
  }) async {
    final json = await _api.postData<Map<String, dynamic>>(
      ApiEndpoints.usuarios,
      body: {
        'username': username,
        'password': password,
        'nombreCompleto': nombreCompleto,
        'rol': rol.name.toUpperCase(),
      },
    );
    return UsuarioModel.fromJson(json);
  }

  @override
  Future<UsuarioModel> actualizar({
    required String id,
    required String nombreCompleto,
    required RolUsuario rol,
    required bool activo,
  }) async {
    final json = await _api.putData<Map<String, dynamic>>(
      ApiEndpoints.usuarioById(id),
      body: {
        'nombreCompleto': nombreCompleto,
        'rol': rol.name.toUpperCase(),
        'activo': activo,
      },
    );
    return UsuarioModel.fromJson(json);
  }

  @override
  Future<void> eliminar(String id) async {
    await _api.deleteData(ApiEndpoints.usuarioById(id));
  }
}
