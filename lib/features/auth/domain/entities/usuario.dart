import 'package:equatable/equatable.dart';

enum RolUsuario { vendedor, encargado, administrador }

/// Entidad pura del dominio. Sin JSON, sin SQL, sin Flutter.
class Usuario extends Equatable {
  const Usuario({
    required this.id,
    required this.username,
    required this.nombreCompleto,
    required this.rol,
    required this.activo,
  });

  final String id;
  final String username;
  final String nombreCompleto;
  final RolUsuario rol;
  final bool activo;

  bool get esAdministrador => rol == RolUsuario.administrador;
  bool get esEncargado => rol == RolUsuario.encargado;
  bool get puedeCorregir => esAdministrador || esEncargado;

  @override
  List<Object?> get props => [id, username, nombreCompleto, rol, activo];
}
