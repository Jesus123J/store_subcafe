import '../../domain/entities/usuario.dart';

class UsuarioModel extends Usuario {
  const UsuarioModel({
    required super.id,
    required super.username,
    required super.nombreCompleto,
    required super.rol,
    required super.activo,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id'] as String,
      username: json['username'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      rol: _parseRol(json['rol'] as String),
      activo: json['activo'] as bool? ?? true,
    );
  }

  static RolUsuario _parseRol(String value) {
    switch (value.toUpperCase()) {
      case 'ADMINISTRADOR':
        return RolUsuario.administrador;
      case 'ENCARGADO':
        return RolUsuario.encargado;
      case 'VENDEDOR':
      default:
        return RolUsuario.vendedor;
    }
  }
}
