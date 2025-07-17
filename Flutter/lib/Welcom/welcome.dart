import 'package:flutter/material.dart';

import '../User/login.dart';
import '../User/sign_up1.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF034985), Color(0xFF1E3C72)], // Gradient colors
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Positioned image with specific dimensions and margins
          Positioned(
            top: 150, // Distance from the top of the page
            left: 30.0, // Distance from the left of the page
            right: 30.0,
            child: SizedBox(
              width: screenWidth * 0.6, // 60% of screen width
              height: screenHeight * 0.3, // 30% of screen height
              child: AnimatedOpacity(
                opacity: 1.0, // Fade-in effect
                duration: Duration(seconds: 1),
                child: Image.asset('images/logo3.png'),
              ),
            ),
          ),

          // Bottom centered container with increased height and curved corners
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: screenHeight * 0.45, // 45% of screen height
              width: double.infinity,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)), // Curved corners at the top
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome!',
                      style: TextStyle(
                        color: Color(0xFF034985),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We are glad to have you here.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Let's get started!",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30.0),
                    // Button Row with animation
                    Column(
                      children: [
                        // Sign Up Button
                        AnimatedContainer(
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignUpScreen()),
                              ); // Use named route for Login
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: const Color(0xFF034985), // Text color
                              backgroundColor: Colors.white, // Button color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12), // Rounded corners
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16.0),
                              shadowColor: Colors.black.withOpacity(0.5), // Shadow color
                              elevation: 8, // Elevation for shadow effect
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add, color: Color(0xFF034985)), // Sign Up icon
                                SizedBox(width: 8), // Spacing
                                Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        // Sign In Button
                        AnimatedContainer(
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => Login()),
                              ); // Use named route for Login
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: const Color(0xFF034985), // Text color
                              backgroundColor: Colors.white, // Button color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12), // Rounded corners
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16.0),
                              shadowColor: Colors.black.withOpacity(0.5), // Shadow color
                              elevation: 8, // Elevation for shadow effect
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login, color: Color(0xFF034985)), // Sign In icon
                                SizedBox(width: 8), // Spacing
                                Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
