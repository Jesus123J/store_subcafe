import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/usuario.dart';

/// Contrato abstracto. La implementación vive en data/.
abstract class AuthRepository {
  Future<Either<Failure, Usuario>> login({
    required String username,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, Usuario?>> getSesionActual();
}
