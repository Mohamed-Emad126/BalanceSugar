class ApiConfig {
  // Base URL
  static const String baseUrl = 'http://192.168.1.42:8000/';

  // Auth endpoints
  static const String login = '$baseUrl/accounts/login/';
  static const String register = '$baseUrl/accounts/register/';
  static const String logout = '$baseUrl/accounts/logout/';
  static const String refreshToken = '$baseUrl/accounts/token/refresh/';
  static const String googleAuth = '$baseUrl/accounts/google/';
  static const String verifyEmail = '$baseUrl/accounts/verify_email/';
  static const String sendResetOtp = '$baseUrl/accounts/send-reset-otp/';
  static const String confirmResetOtp = '$baseUrl/accounts/confirm-reset-otp/';
  static const String resetPassword = '$baseUrl/accounts/reset-password/';

  // User endpoints
  static const String userProfile = '$baseUrl/accounts/profile/';
  static const String updateProfile = '$baseUrl/accounts/profile/';

  // Medication endpoints
  static const String activeMedications =
      '$baseUrl/medication/active_medications/';
  static const String addMedication = '$baseUrl/medication/create/';
  static const String updateMedication = '$baseUrl/medication/update/';
  static const String deleteMedication = '$baseUrl/medication/delete/';
  static const String getMedication = '$baseUrl/medication/';
  static const String medicationTodayUpcoming =
      '$baseUrl/medication/today_upcoming/';
  static const String medicationDay = '$baseUrl/medication/medication_day/';

  // Diet endpoints
  static const String getAllMeals = '$baseUrl/diet/';
  static const String getCalorieInfo = '$baseUrl/diet/calorie_summary/';
  static const String postNutritions = '$baseUrl/diet/nutrition/';
  static const String nutritionSummary = '$baseUrl/diet/nutrition_summary/';
  static const String createMeal = '$baseUrl/diet/create/';
  static const String getFoodItems = '$baseUrl/diet/food/';
  static const String getFoodTypes = '$baseUrl/diet/food_types/';
  static const String recordSteps = '$baseUrl/diet/record_steps/';
  static const String recordCumulativeSteps =
      '$baseUrl/diet/record_cumulative_steps/';
  static const String getStepHistory = '$baseUrl/diet/step_history/';
  static const String stepsToday = '$baseUrl/diet/steps_today/';
  static const String getMealById = '$baseUrl/diet/';
  static const String deleteMeal = '$baseUrl/diet/';
  static const String updateMeal = '$baseUrl/diet/';

  // Footcare endpoints
  static const String footcare = '$baseUrl/footcare';
  static const String ulcersList = '$footcare/ulcers/';
  static const String createUlcer = '$footcare/ulcers/create/';
  static const String deleteUlcersByRegion =
      '$footcare/ulcers/delete_ulcers_by_region/';
  static const String latestByRegion = '$footcare/ulcers/latest_by_region/';
  static const String ulcersByRegion = '$footcare/ulcers/ulcers_by_region/';
  static const String getUlcer = '$footcare/ulcers/';
  static const String deleteUlcer = '$footcare/ulcers/';
  static const String updateUlcer = '$footcare/ulcers/';

  // Measurements endpoints
  static const String addGlucose = '$baseUrl/diabetis/add/';
  static const String glucoseHistory = '$baseUrl/diabetis/history/all/';
  static const String glucoseLast16 = '$baseUrl/diabetis/history/last16/';

  // Chat endpoints
  static const String createChatbot = '$baseUrl/chatbot/api/chatbot/';
  static const String getConversation = '$baseUrl/chatbot/api/conversation/';
  static const String deleteConversation =
      '$baseUrl/chatbot/api/conversation/delete/';
}
