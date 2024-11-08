import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/home_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _parentNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Up',
          style: TextStyle(
            color: Color(0xFFA91B60), // Set text color to Champagne
            fontSize: 24.0, // Font size
            fontWeight: FontWeight.bold, // Font weight
          ),
        ),
        backgroundColor: const Color(0xFFA91B60), // Custom AppBar color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle:
                      const TextStyle(color: Color(0xFFA91B60)), // Label color
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12.0), // Rounded corners
                    borderSide:
                        const BorderSide(color: Color(0xFFA91B60)), // Border color
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  } else if (!value.endsWith('@gmail.com')) {
                    return 'Email must end with @gmail.com';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Parent Name Field
              TextFormField(
                controller: _parentNameController,
                decoration: InputDecoration(
                  labelText: 'Parent Name',
                  labelStyle:
                      const TextStyle(color: Color(0xFFA91B60)), // Label color
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12.0), // Rounded corners
                    borderSide:
                        const BorderSide(color: Color(0xFFA91B60)), // Border color
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the parent\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle:
                      const TextStyle(color: Color(0xFFA91B60)), // Label color
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12.0), // Rounded corners
                    borderSide:
                        const BorderSide(color: Color(0xFFA91B60)), // Border color
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              // Confirm Password Field
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle:
                      const TextStyle(color: Color(0xFFA91B60)), // Label color
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12.0), // Rounded corners
                    borderSide:
                        const BorderSide(color: Color(0xFFA91B60)), // Border color
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),
              // Signup Button
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState?.validate() == true) {
                    final email = _emailController.text;
                    final password = _passwordController.text;
                    final parentName = _parentNameController.text;

                    try {
                      // Insert the user data into Supabase
                      final response = await Supabase.instance.client
                          .from('users')
                          .insert({
                            'email': email,
                            'password': password,
                            'parentName': parentName,
                          })
                          .select('id') // Return the id of the inserted record
                          .single();

                      // Extract the user ID from the response
                      final userID = response['id'];

                      // Navigate to HomePage and pass the userID
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomePage(userID: userID, requestLocation: true)),
                      );

                      // Optionally, show a success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('User signed up successfully')),
                      );
                    } catch (e) {
                      // Handle any errors that occur during the insertion
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFFEBE0D0),
                  backgroundColor: const Color(0xFFA91B60), // Text color
                ),
                child: Text('Sign Up'),
              ),
              const SizedBox(height: 20.0),
              // Navigate to Login Page
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA91B60), // Text color
                ),
                child: Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
