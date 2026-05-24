import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/login_response_model.dart';

abstract class AuthDataSource {
  Future<LoginResponseModel> login(String username, String password);
}

class AuthDataSourceImpl implements AuthDataSource {
  AuthDataSourceImpl(this._api);
  final ApiClient _api;

  @override
  Future<LoginResponseModel> login(String username, String password) async {
    final json = await _api.postData<Map<String, dynamic>>(
      ApiEndpoints.login,
      body: {'username': username, 'password': password},
    );
    return LoginResponseModel.fromJson(json);
  }
}
