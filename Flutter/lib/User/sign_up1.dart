import 'package:balance_sugar/User/verficationpage.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_config.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstnameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final Dio _dio = Dio();

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'first_name': _firstnameController.text,
          'last_name': _lastnameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'password2': _confirmPasswordController.text,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 201) {
        // Store user data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('first_name', _firstnameController.text);
        await prefs.setString('last_name', _lastnameController.text);
        await prefs.setString('email', _emailController.text);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(
                email: _emailController.text,
                onVerificationSuccess: () {
                  // Handle successful verification
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['message'] ?? "Registration failed"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        if (error is DioException) {
          final errorMessage = error.response?.data['message'] ??
              error.message ??
              "Registration failed. Please try again.";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("An unexpected error occurred. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double scaleFactor = MediaQuery.of(context).textScaleFactor;

    return Scaffold(
      backgroundColor: const Color(0XFF034985),
      appBar: _buildAppBar(scaleFactor),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 85 * scaleFactor),
          child: SingleChildScrollView(
            child: Container(
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
                    SizedBox(height: 10 * scaleFactor),
                    _buildFirstnameField(scaleFactor),
                    SizedBox(height: 8 * scaleFactor),
                    _buildLastnameField(scaleFactor),
                    SizedBox(height: 8 * scaleFactor),
                    _buildEmailField(scaleFactor),
                    SizedBox(height: 8 * scaleFactor),
                    _buildPasswordField(scaleFactor),
                    SizedBox(height: 8 * scaleFactor),
                    _buildConfirmPasswordField(scaleFactor),
                    SizedBox(height: 15 * scaleFactor),
                    _buildSignUpButton(scaleFactor),
                    SizedBox(height: 15 * scaleFactor),
                    _buildOrDivider(scaleFactor),
                    SizedBox(height: 15 * scaleFactor),
                    _buildLoginPrompt(context, scaleFactor),
                    SizedBox(height: 12 * scaleFactor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(double scaleFactor) {
    return AppBar(
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
      centerTitle: true,
      title: Text(
        "Sign Up",
        style: TextStyle(
          color: Colors.black,
          fontSize: 22 * scaleFactor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFirstnameField(double scaleFactor) {
    return _buildTextField(
      _firstnameController,
      "First Name",
      Icons.person_outline,
      scaleFactor,
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Please enter your first name';
        return null;
      },
    );
  }

  Widget _buildLastnameField(double scaleFactor) {
    return _buildTextField(
      _lastnameController,
      "Last Name",
      Icons.person_outline,
      scaleFactor,
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Please enter your last name';
        return null;
      },
    );
  }

  Widget _buildEmailField(double scaleFactor) {
    return _buildTextField(
      _emailController,
      "Email",
      Icons.email_outlined,
      scaleFactor,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your email';
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(double scaleFactor) {
    return _buildTextField(
      _passwordController,
      "Password",
      Icons.lock_outline,
      scaleFactor,
      obscureText: true,
      isPassword: true,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField(double scaleFactor) {
    return _buildTextField(
      _confirmPasswordController,
      "Confirm Password",
      Icons.lock_outline,
      scaleFactor,
      obscureText: true,
      isPassword: true,
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Please confirm your password';
        if (value != _passwordController.text) return 'Passwords do not match';
        return null;
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    double scaleFactor, {
    bool obscureText = false,
    bool isPassword = false,
    required String? Function(String?) validator,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText &&
            (isPassword ? _obscurePassword : _obscureConfirmPassword),
        style: TextStyle(
          color: const Color(0X7F000000),
          fontSize: 16 * scaleFactor,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0XFF034985)),
          suffixIcon: obscureText
              ? IconButton(
                  icon: Icon(
                    (isPassword ? _obscurePassword : _obscureConfirmPassword)
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: const Color(0XFF034985),
                  ),
                  onPressed: () {
                    setState(() {
                      if (isPassword) {
                        _obscurePassword = !_obscurePassword;
                      } else {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      }
                    });
                  },
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(
            color: const Color(0X7F000000),
            fontSize: 16 * scaleFactor,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w400,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10 * scaleFactor),
            borderSide: const BorderSide(color: Color(0X8EA5C9ED), width: 0.46),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10 * scaleFactor),
            borderSide: const BorderSide(color: Color(0X8EA5C9ED), width: 0.46),
          ),
          filled: true,
          fillColor: const Color(0XFFFFFFFF),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14 * scaleFactor,
            vertical: 10 * scaleFactor,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSignUpButton(double scaleFactor) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0XFF034985),
        padding: EdgeInsets.symmetric(vertical: 15 * scaleFactor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10 * scaleFactor),
        ),
        minimumSize: Size(double.infinity, 52 * scaleFactor),
      ),
      child: _isLoading
          ? SizedBox(
              height: 24 * scaleFactor,
              width: 24 * scaleFactor,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Create",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18 * scaleFactor,
                  ),
                ),
              ],
            ),
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

  Widget _buildLoginPrompt(BuildContext context, double scaleFactor) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
        );
      },
      child: Center(
        child: Text.rich(
          TextSpan(
            text: "Already have an account ? ",
            style: TextStyle(
              color: const Color(0X7F000000),
              fontSize: 16 * scaleFactor,
            ),
            children: const [
              TextSpan(
                text: "login",
                style: TextStyle(
                  color: Color(0XFF034985),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
