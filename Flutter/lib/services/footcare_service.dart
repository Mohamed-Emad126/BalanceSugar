import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'api_config.dart';
import 'timezone_service.dart';

class FootcareService {
  // Helper to ensure all relevant datetime fields are UTC ISO strings
  static Map<String, dynamic> _convertDateTimesToUtc(
      Map<String, dynamic> data) {
    final newData = Map<String, dynamic>.from(data);
    final dateTimeFields = ['date', 'uploaded_at', 'created_at'];

    for (final field in dateTimeFields) {
      if (newData[field] != null) {
        if (newData[field] is String) {
          try {
            final dt = DateTime.parse(newData[field]);
            newData[field] = TimezoneService.convertToUtcIso(dt);
          } catch (e) {
            // If parsing fails, keep original string
          }
        } else if (newData[field] is DateTime) {
          newData[field] = TimezoneService.convertToUtcIso(newData[field]);
        }
      }
    }

    return newData;
  }

  // Get headers with timezone
  static Future<Map<String, String>> _getHeaders() async {
    return await AuthService.getHeaders();
  }

  // Get list of all ulcers
  static Future<List<Map<String, dynamic>>> getUlcersList() async {
    final response = await http.get(
      Uri.parse(ApiConfig.ulcersList),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to load ulcers: ${response.statusCode}');
    }
  }

  // Create new ulcer record
  static Future<Map<String, dynamic>> createUlcer(
      File imageFile, Map<String, dynamic> data) async {
    var request =
        http.MultipartRequest('POST', Uri.parse(ApiConfig.createUlcer));

    // Add headers
    final headers = await _getHeaders();
    request.headers.addAll(headers);

    // Add image file
    var stream = http.ByteStream(imageFile.openRead());
    var length = await imageFile.length();
    var multipartFile = http.MultipartFile(
      'image',
      stream,
      length,
      filename: 'ulcer_image.jpg',
    );
    request.files.add(multipartFile);

    // Add other data
    final safeData = _convertDateTimesToUtc(data);
    safeData.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    var response = await request.send();
    var responseData = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return json.decode(responseData);
    } else {
      throw Exception('Failed to create ulcer record: ${response.statusCode}');
    }
  }

  // Get specific ulcer details
  static Future<Map<String, dynamic>> getUlcerDetails(String ulcerId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.getUlcer}$ulcerId/'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load ulcer details: ${response.statusCode}');
    }
  }

  // Delete ulcer record
  static Future<void> deleteUlcer(String ulcerId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.deleteUlcer}$ulcerId/delete/'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete ulcer: ${response.statusCode}');
    }
  }

  // Update ulcer record
  static Future<Map<String, dynamic>> updateUlcer(
      String ulcerId, Map<String, dynamic> data,
      {File? newImage}) async {
    if (newImage != null) {
      var request = http.MultipartRequest(
          'PUT', Uri.parse('${ApiConfig.updateUlcer}$ulcerId/update/'));

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add new image file
      var stream = http.ByteStream(newImage.openRead());
      var length = await newImage.length();
      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: 'ulcer_image.jpg',
      );
      request.files.add(multipartFile);

      // Add other data
      final safeData = _convertDateTimesToUtc(data);
      safeData.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception(
            'Failed to update ulcer record: ${response.statusCode}');
      }
    } else {
      final response = await http.put(
        Uri.parse('${ApiConfig.updateUlcer}$ulcerId/update/'),
        headers: {
          ...await _getHeaders(),
          'Content-Type': 'application/json',
        },
        body: json.encode(_convertDateTimesToUtc(data)),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to update ulcer record: ${response.statusCode}');
      }
    }
  }
}
