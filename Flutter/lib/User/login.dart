import 'package:balance_sugar/User/sign_up1.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import '../Welcom/newhome.dart';
import '../password/forgetpassword.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Profile/profile.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isPasswordError = false;
  String _passwordErrorMessage = '';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Login Function
  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Clear any previous password errors
    setState(() {
      _isPasswordError = false;
      _passwordErrorMessage = '';
    });

    setState(() => _isLoading = true);

    try {
      final dio = Dio();
      print('Attempting login to: ${ApiConfig.login}');
      print('Login data: ${emailController.text.trim()}');

      final response = await dio.post(
        ApiConfig.login,
        data: {
          'email': emailController.text.trim(),
          'password': passwordController.text,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response data: ${response.data}');

      if (response.statusCode == 200) {
        // Add a check for response data type
        if (response.data is! Map<String, dynamic>) {
          print('Error: Unexpected response format.');
          _showErrorDialog(
              "The server returned an unexpected response. Please try again later.");
          return;
        }

        if (response.data['access_token'] == null) {
          print('Error: No access token in response');
          _showErrorDialog("Server error: No access token received");
          return;
        }

        // Save tokens
        try {
          await AuthService.saveTokens(
            response.data['access_token'],
            response.data['refreash_token'] ?? response.data['refresh_token'],
          );
          print('Tokens saved successfully');
        } catch (e) {
          print('Error saving tokens: $e');
          print('Access token: ${response.data['access_token']}');
          print('Refresh token: ${response.data['refreash_token']}');
          _showErrorDialog(
              "Failed to save authentication tokens: ${e.toString()}");
          return;
        }

        // Fetch and save user profile
        try {
          print('Fetching user profile from: ${ApiConfig.userProfile}');
          final profileResponse = await dio.get(
            ApiConfig.userProfile,
            options: Options(
              headers: {
                'Authorization': 'Bearer ${response.data['access_token']}'
              },
              validateStatus: (status) => status! < 500,
            ),
          );

          print('Profile response status: ${profileResponse.statusCode}');

          if (profileResponse.statusCode == 200) {
            // The server nests the profile data inside a 'profile' key.
            final responseData = profileResponse.data as Map<String, dynamic>?;
            if (responseData == null || responseData['profile'] is! Map) {
              print('Error: Unexpected profile data format from server.');
              _showErrorDialog(
                  "The server returned an unexpected profile format.");
              return;
            }
            final profileData = responseData['profile'] as Map<String, dynamic>;
            final loginData = response.data;

            try {
              final prefs = await SharedPreferences.getInstance();
              print('Saving user data to SharedPreferences');

              // Handle full_name from login response
              String fullName = loginData['full_name'] ?? '';
              List<String> nameParts = fullName.split(' ');
              String firstName = nameParts.isNotEmpty ? nameParts.first : '';
              String lastName =
                  nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

              // Save all user data
              await Future.wait([
                // From login response
                prefs.setString('first_name', firstName),
                prefs.setString('last_name', lastName),
                prefs.setString('email', loginData['email'] ?? ''),

                // From profile response
                prefs.setString('gender', profileData['gender'] ?? ''),
                prefs.setString('age', profileData['age']?.toString() ?? ''),
                prefs.setString(
                    'diabetes_type', profileData['diabetes_type'] ?? ''),
                prefs.setString('therapy', profileData['therapy'] ?? ''),
                prefs.setString(
                    'weight', profileData['weight']?.toString() ?? ''),
                prefs.setString(
                    'height', profileData['height']?.toString() ?? ''),
                prefs.setString('profile_image', profileData['image'] ?? ''),
              ]);
              print('User data saved successfully');

              // Check if essential profile data is missing and inform the user
              if (profileData['age'] == null ||
                  profileData['weight'] == null ||
                  profileData['height'] == null) {
                if (mounted) {
                  // Non-blocking alert so we can navigate away
                  Future.delayed(
                    const Duration(seconds: 1),
                    () => _showInfoDialog(
                      'Complete Your Profile',
                      'Some of your profile details are missing. Please update them in your profile.',
                    ),
                  );
                }
              }

              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()),
                );
              }
            } catch (e) {
              print('Error saving user data: $e');
              _showErrorDialog("Failed to save user data: ${e.toString()}");
            }
          } else {
            print(
                'Profile fetch failed with status: ${profileResponse.statusCode}');
            print('Profile error response: ${profileResponse.data}');
            _showErrorDialog(
                "Failed to load user profile. Status: ${profileResponse.statusCode}\nError: ${profileResponse.data['message'] ?? 'Unknown error'}");
          }
        } catch (e) {
          print('Error fetching profile: $e');
          _showErrorDialog("Failed to fetch user profile: ${e.toString()}");
        }
      } else {
        print('Login failed with status: ${response.statusCode}');
        print('Login error response: ${response.data}');

        String errorMessage = 'Unknown error';
        String errorTitle = 'Login Failed';

        // Handle specific error cases
        if (response.statusCode == 401) {
          errorTitle = 'Incorrect Password';
          setState(() {
            _isPasswordError = true;
            _passwordErrorMessage = 'Incorrect password';
          });
          if (response.data is Map<String, dynamic>) {
            if (response.data['message'] != null) {
              // Check if the server message indicates password issues
              String serverMessage =
                  response.data['message'].toString().toLowerCase();
              if (serverMessage.contains('password') ||
                  serverMessage.contains('credentials')) {
                errorMessage = response.data['message'];
              } else {
                errorMessage =
                    'The password you entered is incorrect. Please try again.';
              }
            } else {
              errorMessage =
                  'The password you entered is incorrect. Please try again.';
            }
          } else {
            errorMessage =
                'The password you entered is incorrect. Please try again.';
          }
        } else if (response.statusCode == 422) {
          errorTitle = 'Validation Error';
          if (response.data is Map<String, dynamic> &&
              response.data['message'] != null) {
            errorMessage = response.data['message'];
          } else {
            errorMessage = 'Please check your input and try again.';
          }
        } else if (response.statusCode == 404) {
          errorTitle = 'User Not Found';
          errorMessage =
              'No account found with this email address. Please check your email or sign up for a new account.';
        } else if (response.statusCode == 429) {
          errorTitle = 'Too Many Attempts';
          errorMessage =
              'Too many login attempts. Please wait a few minutes before trying again.';
        } else if (response.statusCode == 500) {
          errorTitle = 'Server Error';
          errorMessage = 'Server error occurred. Please try again later.';
        } else if (response.data is Map<String, dynamic> &&
            response.data['message'] != null) {
          errorMessage = response.data['message'];
        } else {
          errorMessage =
              'An unexpected error occurred. Please try again later.';
        }

        _showErrorDialog(errorMessage, title: errorTitle);
      }
    } on DioException catch (e) {
      print('DioException during login:');
      print('Error type: ${e.type}');
      print('Error message: ${e.message}');
      print('Error response: ${e.response?.data}');
      print('Error status: ${e.response?.statusCode}');

      String errorMessage = "Network error occurred";
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage =
            "Connection timeout. Please check your internet connection.";
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = "Server response timeout. Please try again.";
      } else if (e.response?.data != null &&
          e.response?.data['message'] != null) {
        errorMessage = e.response?.data['message'];
      }

      _showErrorDialog("$errorMessage\nStatus: ${e.response?.statusCode}");
    } catch (error) {
      print('Unexpected error during login: $error');
      _showErrorDialog("An unexpected error occurred: ${error.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Show Error Dialog
  void _showErrorDialog(String message, {String title = 'Error'}) {
    print('Showing error dialog: $message');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = (screenWidth / 375 + screenHeight / 812) / 2;

    return Scaffold(
      backgroundColor: const Color(0XFF034985),
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(scaleFactor),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 165 * scaleFactor),
            _buildFormContainer(scaleFactor),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(double scaleFactor) {
    return AppBar(
      centerTitle: true,
      title: Text(
        "Login",
        style: TextStyle(
          color: Colors.black,
          fontSize: 22 * scaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevation: 0,
      toolbarHeight: 60 * scaleFactor,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leadingWidth: 48 * scaleFactor,
      leading: Padding(
        padding: EdgeInsets.only(
          left: 16 * scaleFactor,
          top: 12 * scaleFactor,
          bottom: 12 * scaleFactor,
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Color(0XFF034985),
            size: 24 * scaleFactor,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildFormContainer(double scaleFactor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 20 * scaleFactor),
                _buildTextField(
                  controller: emailController,
                  hintText: "Email",
                  icon: Icons.email_outlined,
                  scaleFactor: scaleFactor,
                  onChanged: (value) {},
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    // Email validation
                    final emailRegex =
                        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8 * scaleFactor),
                _buildTextField(
                  controller: passwordController,
                  hintText: "Password",
                  obscureText: true,
                  icon: Icons.lock_outline,
                  scaleFactor: scaleFactor,
                  isError: _isPasswordError,
                  errorMessage: _passwordErrorMessage,
                  onChanged: (value) {
                    if (_isPasswordError) {
                      setState(() {
                        _isPasswordError = false;
                        _passwordErrorMessage = '';
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (_isPasswordError) {
                      return _passwordErrorMessage;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8 * scaleFactor),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ForgetPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Color(0XFF034985),
                        fontSize: 13 * scaleFactor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16 * scaleFactor),
                _buildSignInButton(scaleFactor),
                SizedBox(height: 15 * scaleFactor),
                _buildOrDivider(scaleFactor),
                SizedBox(height: 15 * scaleFactor),
                _buildSignUpOption(scaleFactor),
                SizedBox(height: 10 * scaleFactor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton(double scaleFactor) {
    return SizedBox(
      width: double.infinity,
      height: 44 * scaleFactor,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0XFF034985),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * scaleFactor),
          ),
        ),
        onPressed: _isLoading
            ? null
            : () {
                if (_formKey.currentState!.validate()) {
                  loginUser();
                }
              },
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Logging in...",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              )
            : const Text(
                "Get Start!",
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    required IconData icon,
    required double scaleFactor,
    bool isError = false,
    String errorMessage = '',
    Function(String)? onChanged,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText && _obscurePassword,
      keyboardType:
          hintText == "Email" ? TextInputType.emailAddress : TextInputType.text,
      onChanged: onChanged,
      style: TextStyle(
        color: const Color(0X7F000000),
        fontSize: 16 * scaleFactor,
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: const Color(0X7F000000),
          fontSize: 16 * scaleFactor,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: const Color(0XFF034985)),
        suffixIcon: obscureText
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0XFF034985),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          borderSide: BorderSide(
            color: isError ? Colors.red : const Color(0X8EA5C9ED),
            width: isError ? 1.5 : 0.46,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          borderSide: BorderSide(
            color: isError ? Colors.red : const Color(0X8EA5C9ED),
            width: isError ? 1.5 : 0.46,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        filled: true,
        fillColor: isError ? Colors.red.shade50 : const Color(0XFFFFFFFF),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14 * scaleFactor,
          vertical: 10 * scaleFactor,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildOrDivider(double scaleFactor) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[350])),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scaleFactor),
          child: Text(
            "OR",
            style: TextStyle(
              color: const Color(0X7F000000),
              fontSize: 18 * scaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[350])),
      ],
    );
  }

  Widget _buildSignUpOption(double scaleFactor) {
    return Center(
      child: Text.rich(
        TextSpan(
          text: "Don't have an account ? ",
          style: TextStyle(
              color: const Color(0X7F000000), fontSize: 16 * scaleFactor),
          children: [
            TextSpan(
              text: "Sign up",
              style: TextStyle(
                color: Color(0XFF034985),
                fontWeight: FontWeight.bold,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SignUpScreen()),
                  );
                },
            ),
          ],
        ),
      ),
    );
  }
}
