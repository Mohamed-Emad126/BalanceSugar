import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';
import 'timezone_service.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class MedicationService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final userTimeZone = await TimezoneService.getUserTimeZone();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Timezone': userTimeZone,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _handleResponse(
    http.Response response,
    String errorMessage,
  ) async {
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 204) {
      return null; // Explicitly handle 204 as success with no content
    } else if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) {
        return null; // For 200/201 with empty body, treat as no content
      }
      final data = json.decode(response.body);
      if (data is List) {
        print('Decoded ${data.length} items from response');
        return data;
      }
      return data;
    } else if (response.statusCode == 401) {
      final newToken = await AuthService.refreshAccessToken();
      if (newToken == null) {
        throw Exception('Authentication failed - please log in again');
      }
      throw Exception('Token expired - please retry');
    }
    throw Exception('$errorMessage (Status: ${response.statusCode})');
  }

  // Get all medications
  static Future<List<dynamic>> getMedications() async {
    try {
      final headers = await _getHeaders();
      print('Fetching medications from: ${ApiConfig.activeMedications}');

      final response = await http.get(
        Uri.parse(ApiConfig.activeMedications),
        headers: headers,
      );

      final data = await _handleResponse(
        response,
        'Failed to load medications',
      );
      if (data is! List) {
        print('Expected List but got: ${data.runtimeType}');
        return [];
      }
      print('Successfully fetched ${data.length} medications');
      return data;
    } catch (e) {
      print('Error getting medications: $e');
      rethrow;
    }
  }

  // Get active medications
  static Future<List<dynamic>> getActiveMedications() async {
    try {
      final headers = await _getHeaders();
      print('Fetching active medications from: ${ApiConfig.activeMedications}');

      final response = await http.get(
        Uri.parse(ApiConfig.activeMedications),
        headers: headers,
      );

      final data = await _handleResponse(
        response,
        'Failed to load active medications',
      );
      if (data is! List) {
        print('Expected List but got: ${data.runtimeType}');
        return [];
      }
      print('Successfully fetched ${data.length} active medications');
      return data;
    } catch (e) {
      print('Error getting active medications: $e');
      rethrow;
    }
  }

  // Create new medication
  static Future<Map<String, dynamic>> createMedication(
    Map<String, dynamic> medicationData,
  ) async {
    try {
      final headers = await _getHeaders();
      final safeData = Map<String, dynamic>.from(
          medicationData); // Use as-is, no UTC conversion
      print('🟢 Pill interaction request body: ${json.encode(safeData)}');
      final response = await http.post(
        Uri.parse(ApiConfig.addMedication),
        headers: headers,
        body: json.encode(safeData),
      );
      print(
          '🟣 Pill interaction API response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Check for interaction warning
        if (data['interaction_warning'] != null) {
          final dynamic warning = data['interaction_warning'];
          // Only proceed if it's a non-empty string or a non-empty map
          if ((warning is String && warning.isNotEmpty) ||
              (warning is Map && warning.isNotEmpty)) {
            final Map<String, String> interactions = {};
            if (warning is String) {
              try {
                // Remove the curly braces and split by commas
                final cleanWarning =
                    warning.replaceAll('{', '').replaceAll('}', '');
                final pairs = cleanWarning.split(',');
                for (var pair in pairs) {
                  final parts = pair.split(':');
                  if (parts.length == 2) {
                    final drug = parts[0].trim().replaceAll("'", "");
                    final message = parts[1].trim().replaceAll("'", "");
                    interactions[drug] = message;
                  }
                }
              } catch (e) {
                print('Error parsing interaction warning: $e');
              }
            } else if (warning is Map) {
              // If it's a map, assume it's already parsed interactions
              warning.forEach((key, value) {
                interactions[key.toString()] = value.toString();
              });
            }

            if (interactions.isNotEmpty) {
              throw DrugInteractionException(
                'Potential drug interactions detected',
                interactions.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .toList(),
              );
            }
          }
        }
        return data;
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          // Retry the request with new token
          final newHeaders = {
            'Authorization': 'Bearer $newToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };
          final retryResponse = await http.post(
            Uri.parse(ApiConfig.addMedication),
            headers: newHeaders,
            body: json.encode(safeData),
          );

          print(
              'Retry create medication response: ${retryResponse.statusCode} - ${retryResponse.body}');

          if (retryResponse.statusCode == 200 ||
              retryResponse.statusCode == 201) {
            final data = json.decode(retryResponse.body);
            // Check for interaction warning
            if (data['interaction_warning'] != null) {
              final dynamic warning = data['interaction_warning'];
              // Only proceed if it's a non-empty string or a non-empty map
              if ((warning is String && warning.isNotEmpty) ||
                  (warning is Map && warning.isNotEmpty)) {
                final Map<String, String> interactions = {};
                if (warning is String) {
                  try {
                    // Remove the curly braces and split by commas
                    final cleanWarning =
                        warning.replaceAll('{', '').replaceAll('}', '');
                    final pairs = cleanWarning.split(',');
                    for (var pair in pairs) {
                      final parts = pair.split(':');
                      if (parts.length == 2) {
                        final drug = parts[0].trim().replaceAll("'", "");
                        final message = parts[1].trim().replaceAll("'", "");
                        interactions[drug] = message;
                      }
                    }
                  } catch (e) {
                    print('Error parsing interaction warning: $e');
                  }
                } else if (warning is Map) {
                  // If it's a map, assume it's already parsed interactions
                  warning.forEach((key, value) {
                    interactions[key.toString()] = value.toString();
                  });
                }

                if (interactions.isNotEmpty) {
                  throw DrugInteractionException(
                    'Potential drug interactions detected',
                    interactions.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .toList(),
                  );
                }
              }
            }
            return data;
          }
        }
        throw Exception('Authentication failed - please log in again');
      }
      throw Exception(
          'Failed to create medication (Status: ${response.statusCode})');
    } catch (e) {
      print('Error creating medication: $e');
      rethrow;
    }
  }

  // Update medication with interaction check
  static Future<Map<String, dynamic>> updateMedication(
    String id,
    Map<String, dynamic> medicationData,
  ) async {
    try {
      final headers = await _getHeaders();
      final safeData = Map<String, dynamic>.from(
          medicationData); // Use as-is, no UTC conversion
      final response = await http.put(
        Uri.parse('${ApiConfig.updateMedication}$id/'),
        headers: headers,
        body: json.encode(safeData),
      );

      print(
          'Update medication response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Check for interaction warning
        if (data['interaction_warning'] != null) {
          final dynamic warning = data['interaction_warning'];
          // Only proceed if it's a non-empty string or a non-empty map
          if ((warning is String && warning.isNotEmpty) ||
              (warning is Map && warning.isNotEmpty)) {
            final Map<String, String> interactions = {};
            if (warning is String) {
              try {
                // Remove the curly braces and split by commas
                final cleanWarning =
                    warning.replaceAll('{', '').replaceAll('}', '');
                final pairs = cleanWarning.split(',');
                for (var pair in pairs) {
                  final parts = pair.split(':');
                  if (parts.length == 2) {
                    final drug = parts[0].trim().replaceAll("'", "");
                    final message = parts[1].trim().replaceAll("'", "");
                    interactions[drug] = message;
                  }
                }
              } catch (e) {
                print('Error parsing interaction warning: $e');
              }
            } else if (warning is Map) {
              // If it's a map, assume it's already parsed interactions
              warning.forEach((key, value) {
                interactions[key.toString()] = value.toString();
              });
            }

            if (interactions.isNotEmpty) {
              throw DrugInteractionException(
                'Potential drug interactions detected',
                interactions.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .toList(),
              );
            }
          }
        }
        return data;
      } else if (response.statusCode == 401) {
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          final newHeaders = {
            'Authorization': 'Bearer $newToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };
          final retryResponse = await http.put(
            Uri.parse('${ApiConfig.updateMedication}$id/'),
            headers: newHeaders,
            body: json.encode(safeData),
          );

          print(
              'Retry update medication response: ${retryResponse.statusCode} - ${retryResponse.body}');

          if (retryResponse.statusCode == 200 ||
              retryResponse.statusCode == 201) {
            final data = json.decode(retryResponse.body);
            // Check for interaction warning
            if (data['interaction_warning'] != null) {
              final dynamic warning = data['interaction_warning'];
              // Only proceed if it's a non-empty string or a non-empty map
              if ((warning is String && warning.isNotEmpty) ||
                  (warning is Map && warning.isNotEmpty)) {
                final Map<String, String> interactions = {};
                if (warning is String) {
                  try {
                    // Remove the curly braces and split by commas
                    final cleanWarning =
                        warning.replaceAll('{', '').replaceAll('}', '');
                    final pairs = cleanWarning.split(',');
                    for (var pair in pairs) {
                      final parts = pair.split(':');
                      if (parts.length == 2) {
                        final drug = parts[0].trim().replaceAll("'", "");
                        final message = parts[1].trim().replaceAll("'", "");
                        interactions[drug] = message;
                      }
                    }
                  } catch (e) {
                    print('Error parsing interaction warning: $e');
                  }
                } else if (warning is Map) {
                  // If it's a map, assume it's already parsed interactions
                  warning.forEach((key, value) {
                    interactions[key.toString()] = value.toString();
                  });
                }

                if (interactions.isNotEmpty) {
                  throw DrugInteractionException(
                    'Potential drug interactions detected',
                    interactions.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .toList(),
                  );
                }
              }
            }
            return data;
          }
        }
        throw Exception('Authentication failed - please log in again');
      }
      throw Exception(
          'Failed to update medication (Status: ${response.statusCode})');
    } catch (e) {
      print('Error updating medication: $e');
      rethrow;
    }
  }

  // Delete medication
  static Future<void> deleteMedication(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.deleteMedication}$id/'),
        headers: headers,
      );
      // No need to process response if 204 is a success and means no content
      if (response.statusCode == 204) {
        print('Medication deleted successfully (Status: 204)');
        return; // Successfully deleted, no further action needed
      }
      await _handleResponse(response, 'Failed to delete medication');
    } catch (e) {
      print('Error deleting medication: $e');
      rethrow;
    }
  }

  // Get single medication
  static Future<Map<String, dynamic>> getMedicationById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.activeMedications}$id/'),
        headers: headers,
      );
      return await _handleResponse(response, 'Failed to get medication');
    } catch (e) {
      print('Error fetching medication: $e');
      rethrow;
    }
  }

  static Future<List<UpcomingMedication>> getUpcomingMedications() async {
    try {
      final headers = await _getHeaders();
      print(
          'Fetching upcoming medications from: ${ApiConfig.medicationTodayUpcoming}');

      final response = await http.get(
        Uri.parse(ApiConfig.medicationTodayUpcoming),
        headers: headers,
      );

      final data = await _handleResponse(
        response,
        'Failed to load upcoming medications',
      );

      if (data is! List) {
        print('Expected List but got: ${data.runtimeType}');
        return [];
      }
      print('Successfully fetched ${data.length} upcoming medications');
      return data.map((json) => UpcomingMedication.fromJson(json)).toList();
    } catch (e) {
      print('Error getting upcoming medications: $e');
      rethrow;
    }
  }

  static Future<List<CalendarMedication>> getCalendarMedicationsForDay(
      DateTime day) async {
    final headers = await _getHeaders();

    // Use the local date as-is (backend should handle timezone conversion)
    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    final url = '${ApiConfig.medicationDay}?date=$dateStr';
    print('📡 Calling medication day API: $url');
    print('📅 Local day: $day');
    print('📅 Date string: $dateStr');

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    print('📡 Response status: ${response.statusCode}');
    print('📡 Response body: ${response.body}');

    final data =
        await _handleResponse(response, 'Failed to load medications for day');
    if (data is! List) {
      print('⚠️ Expected List but got: ${data.runtimeType}');
      return [];
    }

    print('✅ Successfully fetched ${data.length} medications for $dateStr');
    return data.map((json) => CalendarMedication.fromJson(json)).toList();
  }
}

// Custom exception for drug interactions
class DrugInteractionException implements Exception {
  final String message;
  final List<dynamic> interactions;

  DrugInteractionException(this.message, this.interactions);

  @override
  String toString() => message;
}

class UpcomingMedication {
  final String medicationName;
  final String routeOfAdministration;
  final String dosageForm;
  final double dosageQuantityOfUnitsPerTime;
  final String timeForIntake;

  UpcomingMedication({
    required this.medicationName,
    required this.routeOfAdministration,
    required this.dosageForm,
    required this.dosageQuantityOfUnitsPerTime,
    required this.timeForIntake,
  });

  factory UpcomingMedication.fromJson(Map<String, dynamic> json) {
    return UpcomingMedication(
      medicationName: json['medication_name'],
      routeOfAdministration: json['route_of_administration'],
      dosageForm: json['dosage_form'],
      dosageQuantityOfUnitsPerTime:
          double.parse(json['dosage_quantity_of_units_per_time'].toString()),
      timeForIntake: json['time_for_intake'],
    );
  }
}

class CalendarMedication {
  final int id;
  final String medicationName;
  final String routeOfAdministration;
  final String dosageForm;
  final String dosageUnitOfMeasure;
  final double dosageQuantityOfUnitsPerTime;
  final bool equallyDistributedRegimen;
  final String periodicInterval;
  final int dosageFrequency;
  final DateTime firstTimeOfIntake;
  final DateTime stoppedByDatetime;
  final String interactionWarning;

  CalendarMedication({
    required this.id,
    required this.medicationName,
    required this.routeOfAdministration,
    required this.dosageForm,
    required this.dosageUnitOfMeasure,
    required this.dosageQuantityOfUnitsPerTime,
    required this.equallyDistributedRegimen,
    required this.periodicInterval,
    required this.dosageFrequency,
    required this.firstTimeOfIntake,
    required this.stoppedByDatetime,
    required this.interactionWarning,
  });

  factory CalendarMedication.fromJson(Map<String, dynamic> json) {
    return CalendarMedication(
      id: json['id'],
      medicationName: json['medication_name'],
      routeOfAdministration: json['route_of_administration'],
      dosageForm: json['dosage_form'],
      dosageUnitOfMeasure: json['dosage_unit_of_measure'],
      dosageQuantityOfUnitsPerTime:
          (json['dosage_quantity_of_units_per_time'] as num).toDouble(),
      equallyDistributedRegimen: json['equally_distributed_regimen'],
      periodicInterval: json['periodic_interval'],
      dosageFrequency: json['dosage_frequency'],
      firstTimeOfIntake: DateTime.parse(json['first_time_of_intake']),
      stoppedByDatetime: DateTime.parse(json['stopped_by_datetime']),
      interactionWarning: json['interaction_warning'] ?? '',
    );
  }
}
