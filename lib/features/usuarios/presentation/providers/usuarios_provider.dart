import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../auth/data/models/usuario_model.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../../data/datasources/usuarios_datasource.dart';

final usuariosDataSourceProvider = Provider<UsuariosDataSource>((ref) {
  return UsuariosDataSourceImpl(ApiClient.instance);
});

/// Lista de usuarios (auto-refresh cuando se invalida).
final usuariosListProvider =
    FutureProvider.autoDispose<List<UsuarioModel>>((ref) async {
  final ds = ref.watch(usuariosDataSourceProvider);
  return ds.listar();
});

/// Acciones de usuarios.
final usuariosControllerProvider =
    Provider<UsuariosController>((ref) => UsuariosController(ref));

class UsuariosController {
  UsuariosController(this._ref);
  final Ref _ref;

  UsuariosDataSource get _ds => _ref.read(usuariosDataSourceProvider);

  Future<void> crear({
    required String username,
    required String password,
    required String nombreCompleto,
    required RolUsuario rol,
  }) async {
    await _ds.crear(
      username: username,
      password: password,
      nombreCompleto: nombreCompleto,
      rol: rol,
    );
    _ref.invalidate(usuariosListProvider);
  }

  Future<void> actualizar({
    required String id,
    required String nombreCompleto,
    required RolUsuario rol,
    required bool activo,
  }) async {
    await _ds.actualizar(
      id: id,
      nombreCompleto: nombreCompleto,
      rol: rol,
      activo: activo,
    );
    _ref.invalidate(usuariosListProvider);
  }

  Future<void> eliminar(String id) async {
    await _ds.eliminar(id);
    _ref.invalidate(usuariosListProvider);
  }
}
