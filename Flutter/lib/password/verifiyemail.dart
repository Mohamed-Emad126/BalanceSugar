import 'package:balance_sugar/password/CreateNewPassword.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage({Key? key, required this.email}) : super(key: key);

  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;
  bool isResending = false;
  final Dio _dio = Dio();

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  void resendCode() async {
    if (isResending) return;
    setState(() {
      isResending = true;
    });

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new OTP has been sent.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to resend OTP.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isResending = false;
      });
    }
  }

  void verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _dio.post(
        ApiConfig.confirmResetOtp,
        data: {'email': widget.email, 'otp': otpController.text},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;

        // Save the access and refresh tokens
        if (responseData['access_token'] != null &&
            responseData['refresh_token'] != null) {
          await AuthService.saveTokens(
            responseData['access_token'],
            responseData['refresh_token'],
          );

          // Navigate to create new password page with access token
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CreateNewPasswordPage(
                accessToken: responseData['access_token'],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification success, but no tokens received.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['message'] ??
                'OTP verification failed. Please check the code and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (e is DioException) {
        final errorMessage = e.response?.data['message'] ??
            e.message ??
            "Verification failed. Please try again.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF034985),
        appBar: AppBar(
          title: const Text(
            "Verify OTP",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Enter the verification code we just sent on your email address.",
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 30),
                          TextFormField(
                            controller: otpController,
                            decoration: InputDecoration(
                              hintText: "Enter the code",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide:
                                    BorderSide(color: Colors.blueGrey.shade100),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide:
                                    BorderSide(color: Colors.blueGrey.shade100),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide:
                                    BorderSide(color: Colors.blue.shade900),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the OTP';
                              }
                              if (value.length < 6) {
                                return 'OTP must be 6 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : verifyCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF034985),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      "Verify",
                                      style: TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Didn't receive the code? ",
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              GestureDetector(
                                onTap: isResending ? null : resendCode,
                                child: isResending
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
                                          fontSize: 14,
                                          color: Color(0xFF034985),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
