import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/timezone_service.dart';

/// Represents the severity level of a glucose measurement
enum GlucoseSeverity {
  veryLow,
  low,
  normal,
  high,
  dangerous,
}

/// A class representing a blood glucose measurement
///
/// Contains information about the blood glucose level, time of measurement,
/// severity of the reading, and when it was created.
class GlucoseMeasurement {
  final double bloodGlucose;
  final String timeOfMeasurement;
  final GlucoseSeverity severity;
  final DateTime createdAt;
  final double? predictedGlucose;

  /// Creates a new [GlucoseMeasurement] instance
  ///
  /// All parameters are required except [predictedGlucose]:
  /// - [bloodGlucose]: The blood glucose level in mg/dL
  /// - [timeOfMeasurement]: The time when the measurement was taken
  /// - [severity]: The severity level of the glucose reading
  /// - [createdAt]: The timestamp when this record was created
  /// - [predictedGlucose]: Optional predicted glucose level in mg/dL
  const GlucoseMeasurement({
    required this.bloodGlucose,
    required this.timeOfMeasurement,
    required this.severity,
    required this.createdAt,
    this.predictedGlucose,
  });

  /// Creates a [GlucoseMeasurement] instance from a JSON map
  ///
  /// Throws [FormatException] if required fields are missing or have invalid format
  factory GlucoseMeasurement.fromJson(Map<String, dynamic> json) {
    final bloodGlucose = json['blood_glucose'];
    if (bloodGlucose == null) {
      throw const FormatException('blood_glucose is required');
    }

    final timeOfMeasurement = json['time_of_measurement'] as String?;
    if (timeOfMeasurement == null) {
      throw const FormatException('time_of_measurement is required');
    }

    final severityStr = json['severity'] as String?;
    if (severityStr == null) {
      throw const FormatException('severity is required');
    }

    final createdAtStr = json['created_at'] as String?;
    if (createdAtStr == null) {
      throw const FormatException('created_at is required');
    }

    final predictedGlucose = json['predicted_glucose']?.toDouble();

    return GlucoseMeasurement(
      bloodGlucose: bloodGlucose.toDouble(),
      timeOfMeasurement: timeOfMeasurement,
      severity: _parseSeverity(severityStr),
      createdAt: DateTime.parse(createdAtStr),
      predictedGlucose: predictedGlucose,
    );
  }

  /// Converts the measurement to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'blood_glucose': bloodGlucose,
      'time_of_measurement': timeOfMeasurement,
      'severity': _severityToString(severity),
      'created_at': createdAt.toIso8601String(),
      if (predictedGlucose != null) 'predicted_glucose': predictedGlucose,
    };
  }

  /// Gets the color associated with the severity level
  Color getSeverityColor() {
    switch (severity) {
      case GlucoseSeverity.veryLow:
        return Colors.grey;
      case GlucoseSeverity.low:
        return Colors.green;
      case GlucoseSeverity.normal:
        return Colors.orange;
      case GlucoseSeverity.high:
        return Colors.red;
      case GlucoseSeverity.dangerous:
        return Colors.red.shade700;
    }
  }

  /// Gets a display-friendly string representation of the severity level
  String getSeverityText() {
    switch (severity) {
      case GlucoseSeverity.veryLow:
        return 'Very Low';
      case GlucoseSeverity.low:
        return 'Low';
      case GlucoseSeverity.normal:
        return 'Normal';
      case GlucoseSeverity.high:
        return 'High';
      case GlucoseSeverity.dangerous:
        return 'Dangerous';
    }
  }

  /// Gets a formatted date string with the local timezone
  String getFormattedDateTime({String format = 'MMM dd, yyyy HH:mm'}) {
    // Backend already returns timezone-corrected times, so use directly
    return DateFormat(format).format(createdAt);
  }

  /// Gets a detailed description of the measurement
  String getDetailedDescription() {
    final timeFormatted = getFormattedDateTime(format: 'HH:mm');
    final dateFormatted = getFormattedDateTime(format: 'MMM dd, yyyy');

    return '''Blood Glucose: $bloodGlucose mg/dL
Time: $timeFormatted
Date: $dateFormatted
Severity: ${getSeverityText()}''';
  }

  /// Parses a severity string into a [GlucoseSeverity] enum value
  static GlucoseSeverity _parseSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'very low':
        return GlucoseSeverity.veryLow;
      case 'low':
        return GlucoseSeverity.low;
      case 'normal':
        return GlucoseSeverity.normal;
      case 'high':
        return GlucoseSeverity.high;
      case 'dangerous':
        return GlucoseSeverity.dangerous;
      default:
        throw FormatException('Invalid severity value: $severity');
    }
  }

  /// Converts a [GlucoseSeverity] enum value to its string representation
  static String _severityToString(GlucoseSeverity severity) {
    switch (severity) {
      case GlucoseSeverity.veryLow:
        return 'very low';
      case GlucoseSeverity.low:
        return 'low';
      case GlucoseSeverity.normal:
        return 'normal';
      case GlucoseSeverity.high:
        return 'high';
      case GlucoseSeverity.dangerous:
        return 'dangerous';
    }
  }
}
