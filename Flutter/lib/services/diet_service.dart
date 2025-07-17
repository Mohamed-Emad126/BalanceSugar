import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'api_config.dart';
import 'timezone_service.dart';

class Meal {
  final int id;
  final String mealType; // Enum: breakfast, lunch, dinner, snack
  final String name; // Required, minLength: 1
  final String portionSize; // Required, decimal
  final String calories; // Optional, decimal
  final String fat; // Optional, decimal
  final String carbohydrates; // Optional, decimal
  final String protein; // Optional, decimal
  final String sugars; // Optional, decimal

  Meal({
    required this.id,
    required this.mealType,
    required this.name,
    required this.portionSize,
    this.calories = '',
    this.fat = '',
    this.carbohydrates = '',
    this.protein = '',
    this.sugars = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meal_type': mealType,
      'food_name': name,
      'portion_size': portionSize,
      if (calories.isNotEmpty) 'calories': calories,
      if (fat.isNotEmpty) 'fat': fat,
      if (carbohydrates.isNotEmpty) 'carbohydrates': carbohydrates,
      if (protein.isNotEmpty) 'protein': protein,
      if (sugars.isNotEmpty) 'sugars': sugars,
    };
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] ?? 0,
      mealType: json['meal_type'] ?? '',
      name: json['food_name'] ?? '',
      portionSize: json['portion_size']?.toString() ?? '',
      calories: json['calories']?.toString() ?? '',
      fat: json['fat']?.toString() ?? '',
      carbohydrates: json['carbohydrates']?.toString() ?? '',
      protein: json['protein']?.toString() ?? '',
      sugars: json['sugars']?.toString() ?? '',
    );
  }

  // Validation method
  bool isValid() {
    return mealType.isNotEmpty &&
        name.isNotEmpty &&
        name.length >= 1 &&
        portionSize.isNotEmpty;
  }
}

class DietService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
      validateStatus: (status) => status! < 500,
    ),
  );

  // Helper to ensure all relevant datetime fields are UTC ISO strings
  Map<String, dynamic> _convertDateTimesToUtc(Map<String, dynamic> data) {
    final newData = Map<String, dynamic>.from(data);
    final dateTimeFields = ['time_of_meal', 'recorded_at', 'date'];

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
  Future<Map<String, String>> _getHeaders() async {
    return await AuthService.getHeaders();
  }

  // Get all meals
  Future<Map<String, List<Meal>>> getMeals() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.getAllMeals,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final Map<String, List<Meal>> mealsByType = {};
        for (final type in ['breakfast', 'lunch', 'dinner', 'snack']) {
          final List<dynamic> mealList = data[type] ?? [];
          mealsByType[type] = mealList
              .map<Meal>((json) => Meal(
                    id: json['id'] ?? 0,
                    mealType: type,
                    name: json['food_name'] ?? '',
                    portionSize: json['portion_size']?.toString() ?? '',
                    calories: json['calories']?.toString() ?? '',
                    fat: json['fat']?.toString() ?? '',
                    carbohydrates: json['carbohydrates']?.toString() ?? '',
                    protein: json['protein']?.toString() ?? '',
                    sugars: json['sugars']?.toString() ?? '',
                  ))
              .toList();
        }
        return mealsByType;
      }
      throw Exception('Failed to load meals');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Add a new meal
  Future<Meal> addMeal(Meal meal) async {
    try {
      final headers = await _getHeaders();
      final mealData = _convertDateTimesToUtc(meal.toJson());
      final response = await _dio.post(
        ApiConfig.createMeal,
        data: mealData,
        options: Options(headers: headers),
      );
      if (response.statusCode == 201) {
        return Meal.fromJson(response.data);
      }
      throw Exception('Failed to add meal');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Update a meal
  Future<Meal> updateMeal(int mealId, Meal meal) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.put(
        '${ApiConfig.updateMeal}$mealId/update/',
        data: meal.toJson(),
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        return Meal.fromJson(response.data);
      }
      throw Exception('Failed to update meal');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Delete a meal
  Future<void> deleteMeal(int mealId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.delete(
        '${ApiConfig.deleteMeal}$mealId/delete/',
        options: Options(headers: headers),
      );
      if (response.statusCode != 204) {
        throw Exception('Failed to delete meal');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Get meals by type (breakfast, lunch, dinner, snack)
  Future<List<Meal>> getMealsByType(String mealType) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '${ApiConfig.getAllMeals}type/$mealType/',
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Meal.fromJson(json)).toList();
      }
      throw Exception('Failed to load meals by type');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Get meal by ID
  Future<Meal> getMealById(String mealId) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        '${ApiConfig.getMealById}$mealId/',
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        return Meal.fromJson(response.data);
      }
      throw Exception('Failed to load meal');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Get meal calorie info
  Future<Map<String, dynamic>> getMealCalorieInfo() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.getCalorieInfo,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'calories_burned': data['calories_burned_by_steps'],
          'calories_eaten': data['total_calories_consumed'],
          'calorie_goal': data['daily_calorie_goal'],
          'calories_available': data['available_calories'],
        };
      } else {
        throw Exception(
            'Failed to load calorie information: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting calorie info: $e');
    }
  }

  // Get food items
  Future<List<Map<String, dynamic>>> getFoodItems({String? searchQuery}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = searchQuery != null ? {'search': searchQuery} : null;

      final response = await _dio.get(
        ApiConfig.getFoodItems,
        options: Options(headers: headers),
        queryParameters: queryParams,
      );

      if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken == null) {
          throw Exception('Authentication failed. Please log in again.');
        }

        final newHeaders = await _getHeaders();
        final retryResponse = await _dio.get(
          ApiConfig.getFoodItems,
          options: Options(headers: newHeaders),
          queryParameters: queryParams,
        );

        if (retryResponse.statusCode == 200) {
          return _parseFoodItemsResponse(retryResponse.data);
        }
      }

      if (response.statusCode == 200) {
        return _parseFoodItemsResponse(response.data);
      }

      throw Exception('Failed to load food items: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
            'Connection timeout. Please check your internet connection.');
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
            'Server is taking too long to respond. Please try again.');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting food items: $e');
    }
  }

  List<Map<String, dynamic>> _parseFoodItemsResponse(dynamic data) {
    if (data is Map<String, dynamic> && data['foods'] is List) {
      final foodsList = data['foods'] as List;
      return foodsList
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    throw Exception("Invalid response format");
  }

  // Get food types
  Future<List<String>> getFoodTypes() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.getFoodTypes,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        return List<String>.from(response.data);
      } else {
        throw Exception('Failed to load food types: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting food types: $e');
    }
  }

  // Record steps
  Future<Map<String, dynamic>> recordSteps(int stepsCount) async {
    try {
      final headers = await _getHeaders();
      final nowUtc = TimezoneService.getCurrentUtcIso();
      final response = await _dio.post(
        ApiConfig.recordSteps,
        data: {
          'steps_count': stepsCount,
          'recorded_at': nowUtc,
        },
        options: Options(headers: headers),
      );
      if (response.statusCode == 201) {
        return response.data;
      }
      throw Exception('Failed to record steps');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Record cumulative steps from pedometer
  Future<Map<String, dynamic>> recordCumulativeSteps(
      int cumulativeSteps) async {
    try {
      final headers = await _getHeaders();
      final nowUtc = TimezoneService.getCurrentUtcIso();
      final response = await _dio.post(
        ApiConfig.recordCumulativeSteps,
        data: {
          'cumulative_steps': cumulativeSteps,
          'recorded_at': nowUtc,
        },
        options: Options(headers: headers),
      );
      if (response.statusCode == 201) {
        return response.data;
      }
      throw Exception('Failed to record cumulative steps');
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  // Get step history
  Future<List<Map<String, dynamic>>> getStepHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.getStepHistory,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Failed to load step history: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error getting step history: $e');
    }
  }

  // Fetch nutrition info for a specific food and portion size
  Future<Map<String, dynamic>> getFoodNutritionInfo({
    required String foodName,
    required double portionSize,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.post(
        ApiConfig.postNutritions,
        data: {
          'food_name': foodName,
          'portion_size': portionSize,
        },
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception(
            'Failed to fetch nutrition info: \\${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching nutrition info: \\${e.toString()}');
    }
  }

  // Get nutrition summary
  Future<Map<String, dynamic>> getNutritionSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.nutritionSummary,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        throw Exception(
            'Failed to load nutrition summary: \\${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting nutrition summary: \\${e.toString()}');
    }
  }

  // Get today's steps
  Future<Map<String, dynamic>> getStepsToday() async {
    try {
      final headers = await _getHeaders();
      final response = await _dio.get(
        ApiConfig.stepsToday,
        options: Options(headers: headers),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return {
          'steps': data['steps'] ?? 0,
          'calories_burned': data['calories_burned'] ?? '0',
          'distance': data['distance'] ?? '0',
          'date': data['date'],
        };
      } else {
        throw Exception(
            'Failed to load today\'s steps: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting today\'s steps: ${e.toString()}');
    }
  }
}
