import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile.dart';
import 'dart:io';
import '../password/forgetpassword.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/api_config.dart';
import 'dart:convert';
import 'package:balance_sugar/services/profile_service.dart';

class ProfileDrawer extends StatefulWidget {
  @override
  _ProfileDrawerState createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  String _fullName = "Loading...";
  String _userEmail = "Loading...";
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // 1. Load from cache for a responsive UI
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final cachedImage = prefs.getString('profile_image');
    if (mounted) {
      setState(() {
        String firstName = prefs.getString('first_name') ?? "";
        String lastName = prefs.getString('last_name') ?? "";
        _fullName = "$firstName $lastName".trim();
        if (_fullName.isEmpty) _fullName = "No Name";
        _userEmail = prefs.getString('email') ?? "No Email";
        _profileImagePath = cachedImage;
      });
    }

    // 2. Fetch latest data from server
    try {
      final profile = await ProfileService.getProfile();
      // 3. ONLY update cache if server provides a valid URL
      if (profile?.imageUrl != null && profile!.imageUrl!.isNotEmpty) {
        await prefs.setString('profile_image', profile.imageUrl!);
        if (mounted && _profileImagePath != profile.imageUrl) {
          setState(() {
            _profileImagePath = profile.imageUrl;
          });
        }
      } else {}
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFE6EEF5),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF034985)),
            accountName: Text(
              _fullName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: Text(
              _userEmail,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: _getProfileImage(),
              child: _profileImagePath == null || _profileImagePath!.isEmpty
                  ? Icon(Icons.person, size: 40, color: Color(0xFF034985))
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Edit Profile"),
            onTap: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              final userData = UserData(
                firstName: prefs.getString('first_name') ?? "",
                lastName: prefs.getString('last_name') ?? "",
                email: prefs.getString('email') ?? "",
                gender: prefs.getString('gender') ?? "",
                age: prefs.getString('age') ?? "",
                diabetesType: prefs.getString('diabetes_type') ?? "",
                therapy: prefs.getString('therapy') ?? "",
                weight: prefs.getString('weight') ?? "",
                height: prefs.getString('height') ?? "",
              );
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfilePage(user: userData),
                ),
              );

              // Refresh drawer data if profile was updated
              if (result == true) {
                _loadUserData();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text("Contact us"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text("Terms & Policy"),
            onTap: () {},
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              try {
                // Get both access and refresh tokens
                final accessToken = await AuthService.getAccessToken();
                final refreshToken = await AuthService.getRefreshToken();

                if (accessToken != null && refreshToken != null) {
                  // Call the logout API endpoint with refresh token
                  final response = await http.post(
                    Uri.parse(ApiConfig.logout),
                    headers: {
                      'Authorization': 'Bearer $accessToken',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'refresh': refreshToken,
                    }),
                  );

                  if (response.statusCode != 200) {}
                }

                // Clear local storage and tokens regardless of API response
                await AuthService.clearTokens();
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (mounted) {
                  Navigator.pushReplacementNamed(context, "/login");
                }
              } catch (e) {}
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      // Ensure the URL is HTTPS
      final secureUrl = _profileImagePath!.replaceFirst('http://', 'https://');
      if (secureUrl.startsWith('https')) {
        return NetworkImage(secureUrl);
      } else {
        return FileImage(File(_profileImagePath!));
      }
    }
    return null;
  }
}
