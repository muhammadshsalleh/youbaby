import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart'; // Adjust the import based on your directory structure

// Function to show logout confirmation dialog
void showLogoutConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            // color: Color(0xFFA91B60),
            onPressed: () async {
              Navigator.of(context).pop(); // Close the dialog
              await _logout(context); // Call the logout function
            },
            child: const Text("Logout"),
          ),
        ],
      );
    },
  );
}

// Function to handle the logout process
Future<void> _logout(BuildContext context) async {
  try {
    // Call the Supabase signOut method
    await Supabase.instance.client.auth.signOut();
    // Navigate back to the login page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
    );
  } catch (e) {
    // Handle any errors during logout
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error logging out: ${e.toString()}')),
    );
  }
}   
