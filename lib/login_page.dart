import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFFA91B60)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Color(0xFFA91B60)),
                  ),
                ),
                cursorColor: const Color(0xFFA91B60),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Color(0xFFA91B60)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Color(0xFFA91B60)),
                  ),
                ),
                cursorColor: const Color(0xFFA91B60),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30.0),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState?.validate() == true) {
                    final email = _emailController.text;
                    final password = _passwordController.text;

                    try {
                      final response = await Supabase.instance.client
                          .from('users')
                          .select('id, status')
                          .eq('email', email)
                          .eq('password', password)
                          .single();

                      final userID = response['id'];
                      final status = response['status'];

                      // Check if the account is inactive
                      if (status == 'Inactive') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid email or password')),
                        );
                        return;
                      }

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage(userID: userID, requestLocation: true)),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid email or password')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFFEBE0D0),
                  backgroundColor: const Color(0xFFA91B60),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 18.0,
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                child: const Text(
                  'Don\'t have an account? Sign up',
                  style: TextStyle(
                    color: Color(0xFFA91B60),
                    fontSize: 16.0,
                    decoration: TextDecoration.underline,
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