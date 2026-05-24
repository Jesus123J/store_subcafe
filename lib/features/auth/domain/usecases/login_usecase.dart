import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

class LoginParams extends Equatable {
  const LoginParams({required this.username, required this.password});
  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];
}

class LoginUseCase implements UseCase<Usuario, LoginParams> {
  LoginUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, Usuario>> call(LoginParams params) {
    return _repository.login(
      username: params.username,
      password: params.password,
    );
  }
}
