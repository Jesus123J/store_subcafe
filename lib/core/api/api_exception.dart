/// Excepción lanzada por ApiClient cuando el backend retorna error.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
