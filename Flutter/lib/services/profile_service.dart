import 'package:dio/dio.dart';
import 'api_config.dart';
import 'auth_service.dart';

// Profile model class
class Profile {
  final int? user;
  final String? image;
  final String? imageUrl;
  final String? gender;
  final String? therapy;
  final double? weight;
  final double? height;
  final String? diabetesType;
  final int? age;

  Profile({
    this.user,
    this.image,
    this.imageUrl,
    this.gender,
    this.therapy,
    this.weight,
    this.height,
    this.diabetesType,
    this.age,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      user: json['user'],
      image: json['image'],
      imageUrl: json['image_url'],
      gender: json['gender'],
      therapy: json['therapy'],
      weight: json['weight']?.toDouble(),
      height: json['height']?.toDouble(),
      diabetesType: json['diabetes_type'],
      age: json['age'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (gender != null) 'gender': gender,
      if (therapy != null) 'therapy': therapy,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
      if (diabetesType != null) 'diabetes_type': diabetesType,
      if (age != null) 'age': age,
    };
  }
}

class ProfileService {
  static final Dio _dio = Dio();

  // Get headers
  static Future<Map<String, String>> _getHeaders() async {
    return await AuthService.getHeaders();
  }

  // 🟢 Get user profile
  static Future<Profile?> getProfile() async {
    try {
      final headers = await _getHeaders();

      final response = await _dio.get(
        ApiConfig.userProfile,
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        return Profile.fromJson(response.data);
      } else if (response.statusCode == 401) {
        String? newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return getProfile(); // Retry with new token
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      if (e is DioException) {}
      return null;
    }
  }

  // 🟡 Update user profile (PUT - full update)
  static Future<Profile?> updateProfile(Profile profile) async {
    try {
      final headers = await _getHeaders();

      final response = await _dio.put(
        ApiConfig.updateProfile,
        data: profile.toJson(),
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        return Profile.fromJson(response.data);
      } else if (response.statusCode == 401) {
        String? newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return updateProfile(profile); // Retry with new token
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      if (e is DioException) {}
      return null;
    }
  }

  // 🟠 Partial update user profile (PATCH)
  static Future<Profile?> partialUpdateProfile(
      Map<String, dynamic> updates) async {
    try {
      final headers = await _getHeaders();

      final response = await _dio.patch(
        ApiConfig.updateProfile,
        data: updates,
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        return Profile.fromJson(response.data);
      } else if (response.statusCode == 401) {
        String? newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          return partialUpdateProfile(updates); // Retry with new token
        }
        return null;
      } else {
        return null;
      }
    } catch (e) {
      if (e is DioException) {}
      return null;
    }
  }

  // 🟢 Convenience method to update specific fields
  static Future<Profile?> updateProfileFields({
    String? gender,
    String? therapy,
    double? weight,
    double? height,
    String? diabetesType,
    int? age,
  }) async {
    Map<String, dynamic> updates = {};

    if (gender != null) updates['gender'] = gender;
    if (therapy != null) updates['therapy'] = therapy;
    if (weight != null) updates['weight'] = weight;
    if (height != null) updates['height'] = height;
    if (diabetesType != null) updates['diabetes_type'] = diabetesType;
    if (age != null) updates['age'] = age;

    return partialUpdateProfile(updates);
  }

  // 🟢 Get available gender options
  static List<String> getGenderOptions() {
    return ['Male', 'Female'];
  }

  // 🟢 Get available therapy options
  static List<String> getTherapyOptions() {
    return ['Insulin', 'Tablets'];
  }

  // 🟢 Get available diabetes type options
  static List<String> getDiabetesTypeOptions() {
    return [
      'Normal',
      'Type 1',
      'Type 2',
      'Pre Diabetic',
      'Genetic Predisposition',
    ];
  }
}
