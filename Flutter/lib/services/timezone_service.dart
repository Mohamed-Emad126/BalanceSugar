import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class TimezoneService {
  static String? _cachedTimezone;

  /// Get the user's current timezone
  /// Returns timezone in format like "Asia/Tokyo", "America/New_York", etc.
  static Future<String> getUserTimeZone() async {
    if (_cachedTimezone != null) {
      return _cachedTimezone!;
    }

    try {
      String timeZone = await FlutterTimezone.getLocalTimezone();
      _cachedTimezone = timeZone;
      print("✅ Detected timezone: $timeZone");
      return timeZone;
    } catch (e) {
      print("❌ Error detecting timezone: $e");

      // Fallback: Try to get timezone from system
      try {
        final fallbackTimezone = _getFallbackTimezone();
        _cachedTimezone = fallbackTimezone;
        print("✅ Using fallback timezone: $fallbackTimezone");
        return fallbackTimezone;
      } catch (fallbackError) {
        print("❌ Fallback timezone detection failed: $fallbackError");
        // Final fallback to UTC
        _cachedTimezone = "UTC";
        return "UTC";
      }
    }
  }

  /// Fallback method to get timezone when flutter_timezone fails
  static String _getFallbackTimezone() {
    try {
      // Get the current timezone offset
      final now = DateTime.now();
      final utc = now.toUtc();
      final difference = now.difference(utc);

      // Convert to timezone string format
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);

      if (hours == 0 && minutes == 0) {
        return "UTC";
      }

      final sign = hours >= 0 ? "+" : "-";
      final absHours = hours.abs();
      final timezoneString =
          "UTC$sign${absHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";

      return timezoneString;
    } catch (e) {
      print("Error in fallback timezone detection: $e");
      return "UTC";
    }
  }

  /// Convert a local DateTime to UTC ISO string
  /// This is used for sending datetime data to the backend
  static String convertToUtcIso(DateTime localDateTime) {
    return localDateTime.toUtc().toIso8601String();
  }

  /// Convert a UTC ISO string to DateTime (no .toLocal())
  /// This is used for displaying datetime data from the backend
  static DateTime convertFromUtcIso(String utcIsoString) {
    return DateTime.parse(utcIsoString);
  }

  /// Get current time in UTC ISO format
  static String getCurrentUtcIso() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// Clear cached timezone (useful for testing or when timezone changes)
  static void clearCache() {
    _cachedTimezone = null;
  }

  /// Debug function to print the detected timezone
  static Future<void> debugPrintUserTimeZone() async {
    String tz = await getUserTimeZone();
    print("🕒 Detected local timezone: $tz");
  }

  /// Format a backend ISO string in the user's detected timezone
  static Future<String> formatInUserTimezone(String isoString,
      {String pattern = 'hh:mm a'}) async {
    try {
      final userTz = await getUserTimeZone();
      final location = tz.getLocation(userTz);
      final dt = DateTime.parse(isoString);
      final tzDt = tz.TZDateTime.from(dt, location);
      return DateFormat(pattern).format(tzDt);
    } catch (e) {
      print('Timezone formatting error: $e');
      return 'Invalid time';
    }
  }
}
