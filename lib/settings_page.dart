import 'package:flutter/material.dart';
import 'setting_profile.dart'; // Import the PrivacySecurityPage file
import 'setting_notification.dart';
import 'setting_privacy.dart';
import 'setting_language.dart';
import 'setting_data.dart';
import 'setting_subscription.dart';
import 'setting_help.dart';
import 'logout.dart';
import 'package:flutter_localization/flutter_localization.dart';


class SettingsPage extends StatefulWidget {

  final int userID;

  const SettingsPage({super.key, required this.userID});
  @override
  _SettingsPage createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', 
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: ListView(
        children: [
          //Profile Settings
          SettingsTile(
            icon: Icons.person,
            title: 'Profile Settings',
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ProfileSettingsPage(userID: widget.userID)));
            },
          ),
          Divider(),

          // Notification Settings
          SettingsTile(
            icon: Icons.notifications,
            title: 'Notification Settings',
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => NotificationSettingsPage()));
            },
          ),
          Divider(),

          // Privacy & Security
          // SettingsTile(
          //   icon: Icons.lock,
          //   title: 'Privacy & Security',
          //   onTap: () {
          //     Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //             builder: (context) => PrivacySecurityPage()));
          //   },
          // ),
          // Divider(),

          // Language Settings
          SettingsTile(
            icon: Icons.language,
            title: 'Language',
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LanguageSettingsPage()));
            },
          ),
          Divider(),

          // Data Management
          // SettingsTile(
          //   icon: Icons.storage,
          //   title: 'Data Management',
          //   onTap: () {
          //     Navigator.push(
          //         context,
          //         MaterialPageRoute(
          //             builder: (context) => DataManagementPage()));
          //   },
          // ),
          // Divider(),

          // Subscription & Payment
          SettingsTile(
            icon: Icons.payment,
            title: 'Subscription & Payment',
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SubscriptionPaymentPage()));
            },
          ),
          Divider(),

          // Help & Support
          SettingsTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => HelpSupportPage()));
            },
          ),
          Divider(),

          // Logout
          SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () {
              showLogoutConfirmationDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Logout functionality
                Navigator.of(context).pop();
                // Implement logout functionality here
              

              },
              child: Text("Logout"),
            ),
          ],
        );
      },
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  SettingsTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFFA81B60)),
      title: Text(title),
      trailing: Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}

// Sample placeholder pages for each settings option.
// class ProfileSettingsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Profile Settings")),
//       body: Center(child: Text("Profile Settings Page")),
//     );
//   }
// }

// class NotificationSettingsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Notification Settings")),
//       body: Center(child: Text("Notification Settings Page")),
//     );
//   }
// }

// class PrivacySecurityPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Privacy & Security")),
//       body: Center(child: Text("Privacy & Security Page")),
//     );
//   }
// }

// class LanguageSettingsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Language Settings")),
//       body: Center(child: Text("Language Settings Page")),
//     );
//   }
// }

// class DataManagementPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Data Management")),
//       body: Center(child: Text("Data Management Page")),
//     );
//   }
// }

// class SubscriptionPaymentPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Subscription & Payment")),
//       body: Center(child: Text("Subscription & Payment Page")),
//     );
//   }
// }

// class HelpSupportPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Help & Support")),
//       body: Center(child: Text("Help & Support Page")),
//     );
//   }
// }
