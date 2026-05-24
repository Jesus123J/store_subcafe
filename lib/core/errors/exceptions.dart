/// Excepciones lanzadas en la capa de Data.
/// Se capturan en los Repositories y se convierten en Failures.

class DatabaseException implements Exception {
  DatabaseException(this.message);
  final String message;

  @override
  String toString() => 'DatabaseException: $message';
}

class NotFoundException implements Exception {
  NotFoundException(this.message);
  final String message;

  @override
  String toString() => 'NotFoundException: $message';
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
