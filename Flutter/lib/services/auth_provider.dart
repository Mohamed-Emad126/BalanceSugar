import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;

  // You can add your own sign-in methods here if needed

  Future<bool> isSignedIn() async {
    final token = await AuthService.getAccessToken();
    return token != null;
  }
}
