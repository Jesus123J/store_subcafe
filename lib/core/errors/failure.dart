import 'package:equatable/equatable.dart';

/// Clase base para representar errores en el dominio.
/// Se retorna en `Either<Failure, T>` en lugar de lanzar excepciones.
abstract class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
