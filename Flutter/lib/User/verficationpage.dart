import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../Profile/user.dart';
import '../Welcom/newhome.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerificationSuccess;

  const VerifyEmailScreen({
    Key? key,
    required this.email,
    required this.onVerificationSuccess,
  }) : super(key: key);

  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  final Dio _dio = Dio();

  Future<void> _verifyOtp() async {
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the OTP"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _dio.post(
        ApiConfig.verifyEmail,
        data: {'email': widget.email, 'otp': otpController.text},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        await AuthService.saveTokens(
          responseData['access_token'],
          responseData['refresh_token'],
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => User(
                onContinue: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DashboardPage()),
                  );
                },
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['message'] ?? "OTP verification failed",
              ),
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
              "Verification failed. Please try again.";
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

  Future<void> _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    try {
      await _dio.post(
        ApiConfig.sendResetOtp,
        data: {'email': widget.email},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new OTP has been sent.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend OTP.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF034985),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Verification",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: screenWidth > 400 ? 400 : screenWidth * 0.95,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "OTP Verification",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter the verification code we just sent on your email address.",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: otpController,
                  decoration: InputDecoration(
                    hintText: "Enter the OTP",
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF034985)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF034985), width: 2),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF034985),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Verify",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        "Don't receive the OTP?",
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _isResending ? null : _resendCode,
                        child: _isResending
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Send it again",
                                style: TextStyle(
                                  color: Color(0xFF034985),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
