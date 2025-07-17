import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Measurements/glucose_measurement.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'timezone_service.dart';

class GlucoseService {
  Future<Map<String, String>> _getHeaders() async {
    return await AuthService.getHeaders();
  }

  Future<List<GlucoseMeasurement>> getGlucoseHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.glucoseHistory),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => GlucoseMeasurement.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        // Try to refresh token and retry
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getGlucoseHistory(); // Retry with new token
        }
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to load glucose history');
      }
    } catch (e) {
      throw Exception('Error fetching glucose history: $e');
    }
  }

  Future<List<GlucoseMeasurement>> getLast16Measurements() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.glucoseLast16),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => GlucoseMeasurement.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        // Try to refresh token and retry
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getLast16Measurements(); // Retry with new token
        }
        throw Exception('Authentication failed');
      } else {
        throw Exception('Failed to load last 16 measurements');
      }
    } catch (e) {
      throw Exception('Error fetching last 16 measurements: $e');
    }
  }

  Future<void> addGlucoseMeasurement({
    required double bloodGlucose,
    required String timeOfMeasurement,
    required DateTime timestamp,
  }) async {
    try {
      final headers = await _getHeaders();
      // Ensure timestamp is sent as UTC ISO string
      final utcTimestamp = TimezoneService.convertToUtcIso(timestamp);
      final response = await http.post(
        Uri.parse(ApiConfig.addGlucose),
        headers: headers,
        body: json.encode({
          'blood_glucose': bloodGlucose,
          'time_of_measurement': timeOfMeasurement,
          'created_at': utcTimestamp,
        }),
      );

      if (response.statusCode == 201) {
        // No need to parse response body if not needed by the caller
        return; // Indicate success
      } else if (response.statusCode == 401) {
        // Try to refresh token and retry
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return addGlucoseMeasurement(
            bloodGlucose: bloodGlucose,
            timeOfMeasurement: timeOfMeasurement,
            timestamp: timestamp,
          ); // Retry with new token
        }
        throw Exception('Authentication failed');
      } else {
        // Include response body in error message for better debugging
        final errorBody = response.body.isNotEmpty
            ? response.body
            : 'No error details provided.';
        throw Exception(
            'Failed to add glucose measurement: Status code ${response.statusCode}, Details: $errorBody');
      }
    } catch (e) {
      throw Exception('Error adding glucose measurement: $e');
    }
  }
}
