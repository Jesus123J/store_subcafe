import 'usuario_model.dart';

class LoginResponseModel {
  LoginResponseModel({
    required this.token,
    required this.expiresIn,
    required this.usuario,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      token: json['token'] as String,
      expiresIn: (json['expiresIn'] as num).toInt(),
      usuario: UsuarioModel.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  final String token;
  final int expiresIn;
  final UsuarioModel usuario;
}
