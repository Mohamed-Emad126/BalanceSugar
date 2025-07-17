import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'api_config.dart';
import 'timezone_service.dart';

class AuthService {
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final Dio _dio = Dio();

  // 🟢 Save tokens securely
  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    try {
      await _secureStorage.write(key: 'access_token', value: accessToken);
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    } catch (e) {
      throw Exception('Failed to save authentication tokens');
    }
  }

  // ✅ Get access token from secure storage
  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: 'access_token');
    } catch (e) {
      return null;
    }
  }

  // ✅ Get refresh token from secure storage
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: 'refresh_token');
    } catch (e) {
      return null;
    }
  }

  // 🟠 Refresh access token when expired
  static Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      return null;
    }

    try {
      final userTimeZone = await TimezoneService.getUserTimeZone();
      final response = await _dio.post(
        ApiConfig.refreshToken,
        data: {'refresh': refreshToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Timezone': userTimeZone,
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        String newAccessToken = response.data['access'];
        await _secureStorage.write(key: 'access_token', value: newAccessToken);
        return newAccessToken;
      } else {
        return null;
      }
    } catch (e) {
      if (e is DioException) {}
      return null;
    }
  }

  // 🔴 Remove tokens (logout)
  static Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
    } catch (e) {
      throw Exception('Failed to clear authentication tokens');
    }
  }

  // Get headers with auth token and timezone
  static Future<Map<String, String>> getHeaders() async {
    final token = await getAccessToken();
    final userTimeZone = await TimezoneService.getUserTimeZone();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Timezone': userTimeZone,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
