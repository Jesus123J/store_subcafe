import 'package:dartz/dartz.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/auth_token_storage.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource, this._tokenStorage);

  final AuthDataSource _datasource;
  final AuthTokenStorage _tokenStorage;

  @override
  Future<Either<Failure, Usuario>> login({
    required String username,
    required String password,
  }) async {
    try {
      final res = await _datasource.login(username, password);
      await _tokenStorage.save(res.token);
      return Right(res.usuario);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        return const Left(AuthFailure('Usuario o contraseña incorrectos'));
      }
      if (e.isNetworkError) {
        return Left(NetworkFailure(e.message));
      }
      return Left(UnknownFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    await _tokenStorage.clear();
    return const Right(null);
  }

  @override
  Future<Either<Failure, Usuario?>> getSesionActual() async {
    if (_tokenStorage.token == null) return const Right(null);
    return const Right(null);
  }
}
