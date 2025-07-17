import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'services/api_config.dart';
import 'services/auth_provider.dart';
import 'services/timezone_service.dart';
import 'Medications/Firstmed.dart';
import 'User/login.dart';
import 'User/sign_up1.dart';
import 'Welcom/newhome.dart';
import 'Welcom/splash.dart';
import 'Welcom/welcome.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> requestPermissions() async {
  // Request activity recognition permission for pedometer
  await Permission.activityRecognition.request();

  // Request storage permission if needed
  await Permission.storage.request();

  // Request location permission if needed
  await Permission.location.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Request permissions before proceeding
  await requestPermissions();

  // Initialize timezone service
  try {
    await TimezoneService.getUserTimeZone();
    print("✅ Timezone service initialized successfully");
    // Debug: Print the detected timezone
    await TimezoneService.debugPrintUserTimeZone();
  } catch (e) {
    print("⚠️ Timezone service initialization failed: $e");
  }

  final storage = FlutterSecureStorage();
  final String? token = await storage.read(key: 'access_token');
  bool isLoggedIn = false;

  if (token != null && token.isNotEmpty) {
    try {
      final userTimeZone = await TimezoneService.getUserTimeZone();
      final response = await Dio().get(
        ApiConfig.userProfile,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'User-Timezone': userTimeZone,
          },
        ),
      );
      if (response.statusCode == 200) {
        isLoggedIn = true;
      } else {
        await storage.delete(key: 'access_token');
        isLoggedIn = false;
      }
    } catch (e) {
      await storage.delete(key: 'access_token');
      isLoggedIn = false;
    }
  }

  runApp(DiabetesApp(isLoggedIn: isLoggedIn));
}

class DiabetesApp extends StatelessWidget {
  final bool isLoggedIn;
  const DiabetesApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF034985),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Montserrat',
        ),
        home: isLoggedIn ? const DashboardPage() : const SplashPage(),
        routes: {
          '/splash': (context) => const SplashPage(),
          '/welcome': (context) => const WelcomePage(),
          '/login': (context) => const Login(),
          '/sign_up': (context) => const SignUpScreen(),
          '/dashboard': (context) => const DashboardPage(),
          '/medications': (context) => PillReminderScreen(),
        },
      ),
    );
  }
}
