import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youbaby/main.dart'; // Replace with your actual import

void main() {
  testWidgets('Welcome Page has all required elements',
      (WidgetTester tester) async {
    // Build the WelcomePage widget tree
    await tester.pumpWidget(MyApp());

    // Check if the logo is present
    expect(find.byType(Image), findsWidgets);

    // Check if the welcome text is present
    expect(find.text('Welcome to youbaby'), findsOneWidget);

    // Check if the Login button is present and has the correct text
    expect(find.text('Login'), findsOneWidget);

    // Check if the Sign Up button is present and has the correct text
    expect(find.text('Sign Up'), findsOneWidget);

    // Check if the trademark text is present
    expect(find.text('© 2024 Youbaby Million Sdn Bhd. All rights reserved.'),
        findsOneWidget);
  });

  testWidgets('Navigation to Home Page works', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Tap on the 'Login' button
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Verify that after tapping, we navigate to the HomePage
    expect(find.text('This is the Home Page'), findsOneWidget);
  });
}
