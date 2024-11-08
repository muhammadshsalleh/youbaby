import 'package:flutter/material.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          // Ensure all elements are centered horizontally
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center horizontally
            children: <Widget>[
              // Logo Image at the top
              Container(
                child: Image.asset(
                  'assets/logo.png',
                  height: screenWidth * 0.4, // 40% of screen width
                  width: screenWidth * 0.4,
                ),
              ),
              SizedBox(height: screenHeight * 0.05),

              // Welcome Text
              Text(
                'Welcome to Youbaby',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.08, // 8% of screen width
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA91B60), // Pink color
                ),
              ),
              SizedBox(height: screenHeight * 0.05),

              // Login Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                      context, '/login'); // Navigate to login page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA91B60),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.15,
                    vertical: screenHeight * 0.02,
                  ),
                  minimumSize:
                      Size(screenWidth * 0.5, 50.0), // Adjust button size
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
                child: Text(
                  'Login',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05, // 5% of screen width
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.03),

              // Sign Up Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                      context, '/signup'); // Navigate to signup page
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFFA91B60),
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.15,
                    vertical: screenHeight * 0.02,
                  ),
                  minimumSize:
                      Size(screenWidth * 0.5, 50.0), // Adjust button size
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    side: const BorderSide(color: Color(0xFFA91B60)),
                  ),
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05, // 5% of screen width
                    color: const Color(0xFFA91B60),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.08),

              // Trademark Notice
              Padding(
                padding: EdgeInsets.all(screenWidth * 0.03),
                child: Text(
                  '© 2024 Youbaby Million Sdn Bhd. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: screenWidth * 0.03, // 3% of screen width
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
