import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../utils/logger.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'auth_token_storage.dart';

/// Cliente HTTP singleton para consumir el backend Spring Boot.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        compact: true,
        maxWidth: 100,
      ),
    ]);
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  Dio get dio => _dio;

  /// GET helper que extrae el campo `data` del ApiResponse del backend.
  Future<T> getData<T>(String path, {Map<String, dynamic>? query}) async {
    return _wrap<T>(() => _dio.get(path, queryParameters: query));
  }

  Future<T> postData<T>(String path, {Object? body}) async {
    return _wrap<T>(() => _dio.post(path, data: body));
  }

  Future<T> putData<T>(String path, {Object? body}) async {
    return _wrap<T>(() => _dio.put(path, data: body));
  }

  Future<void> deleteData(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> _wrap<T>(Future<Response<dynamic>> Function() req) async {
    try {
      final res = await req();
      final body = res.data;
      if (body is Map && body.containsKey('data')) {
        return body['data'] as T;
      }
      return body as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final code = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    String message;
    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      message = 'No se pudo conectar al servidor. Verifique su conexión.';
    } else {
      message = e.message ?? 'Error desconocido';
    }
    logger.w('API error [$code]: $message');
    return ApiException(statusCode: code, message: message);
  }
}

/// Interceptor que adjunta automáticamente el JWT en cada request.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = AuthTokenStorage.instance.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expirado: borrarlo
      AuthTokenStorage.instance.clear();
    }
    handler.next(err);
  }
}
