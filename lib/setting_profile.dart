import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  final int userID;

  const ProfileSettingsPage({Key? key, required this.userID}) : super(key: key);

  @override
  _ProfileSettingsPageState createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _emailPasswordController =
      TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isEditingEmail = false;
  bool _isChangingPassword = false;
  String _currentEmail = '';
  String _currentPassword = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    _emailPasswordController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('email, password')
          .eq('id', widget.userID)
          .single();

      setState(() {
        _currentEmail = response['email'];
        _currentPassword = response['password'];
      });
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _saveEmailChanges() async {
    if (_newEmailController.text.isEmpty ||
        _emailPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Please enter a new email and your current password")),
      );
      return;
    }

    try {
      // Verify the current password
      if (_emailPasswordController.text != _currentPassword) {
        throw Exception('Invalid password');
      }

      // Update email in the database
      await Supabase.instance.client
          .from('users')
          .update({'email': _newEmailController.text}).eq('id', widget.userID);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email updated successfully")),
      );
      setState(() {
        _currentEmail = _newEmailController.text;
        _isEditingEmail = false;
        _newEmailController.clear();
        _emailPasswordController.clear();
      });
      _fetchUserData(); // Refresh user data
    } catch (e) {
      print('Error updating email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update email: ${e.toString()}")),
      );
    }
  }

  Future<void> _savePasswordChanges() async {
    if (_currentPasswordController.text != _currentPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current password is incorrect")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
      );
      return;
    }

    try {
      // Update password in the database
      await Supabase.instance.client.from('users').update(
          {'password': _passwordController.text}).eq('id', widget.userID);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password updated successfully")),
      );
      setState(() {
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
      _fetchUserData(); // Refresh user data
    } catch (e) {
      print('Error updating password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update password: ${e.toString()}")),
      );
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .update({'status': 'Inactive'}).eq('id', widget.userID);

      if (response != null) {
        throw Exception('Failed to update account status');
      }

      // Call the Supabase signOut method
      await Supabase.instance.client.auth.signOut();
      // Navigate back to the login page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully")),
      );
    } catch (e) {
      print('Error updating account status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Error deleting acccount, please try again later. Code: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Settings",
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA81B60),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmailSection(),
            const SizedBox(height: 24),
            _buildPasswordSection(),
            const SizedBox(height: 24),
            _buildDeleteAccountSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _isEditingEmail
                  ? Column(
                      children: [
                        TextField(
                          controller: _newEmailController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'New email',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailPasswordController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Current password',
                          ),
                          obscureText: true,
                        ),
                      ],
                    )
                  : Text(
                      _currentEmail,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 97, 96, 96),
                        fontSize: 16
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                
                setState(() {
                  if (_isEditingEmail) {
                    _saveEmailChanges();
                  } else {
                    _isEditingEmail = true;
                    _newEmailController.text = _currentEmail;
                  }
                });
              },
               style: TextButton.styleFrom(
                foregroundColor: Color(0xFFA81B60), // Set the text color
              ),
              child: Text(_isEditingEmail ? "Save" : "Edit"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (!_isChangingPassword)
          ElevatedButton(
            onPressed: () => setState(() => _isChangingPassword = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFA81B60), // Set the background color
              foregroundColor: Colors.white, // Set the text color
            ),
            child: const Text("Change Password"),
          )
        else ...[
          TextField(
            controller: _currentPasswordController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Current password',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'New password',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Confirm new password',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _savePasswordChanges,
             style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFA81B60), // Set the background color
              foregroundColor: Colors.white, // Set the text color
            ),
            child: const Text("Change Password"),
          ),
        ],
      ],
    );
  }

  Widget _buildDeleteAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Deletion:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _showDeleteAccountDialog,
          child: const Text("Deactivate Account"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            // padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Deactivate Account"),
          content: const Text(
              "Are you sure you want to deactivate account? This action cannot be undone."),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Deactivate"),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }
}
