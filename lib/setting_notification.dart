import 'package:flutter/material.dart';
import 'package:youbaby/settings_page.dart';

class NotificationSettingsPage extends StatefulWidget {
  @override
  _NotificationSettingsPageState createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // State variables for toggles
  bool _update = true;
  bool _newpost = true;
  bool _likes = true;
  bool _reply = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notification Settings", 
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          )),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'App Notifications',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFFA81B60),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Using custom SettingsSwitchTile for toggles
            SettingsSwitchTile(
              title: 'Recent Updates',
              value: _update,
              onChanged: (bool value) {
                setState(() {
                  _update = value; // Update the _update variable
                });
              },
            ),
            Divider(),

            SettingsSwitchTile(
              title: 'New Posts',
              value: _newpost,
              onChanged: (bool value) {
                setState(() {
                  _newpost = value; // Update the _newpost variable
                });
              },
            ),
            Divider(),

            SettingsSwitchTile(
              title: 'Likes',
              value: _likes,
              onChanged: (bool value) {
                setState(() {
                  _likes = value; // Update the _likes variable
                });
              },
            ),
            Divider(),

            SettingsSwitchTile(
              title: 'Replies',
              value: _reply,
              onChanged: (bool value) {
                setState(() {
                  _reply = value; // Update the _reply variable
                });
              },
            ),
            Divider(),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          // fontWeight: FontWeight.w500,
          color: Colors.grey[800], // Custom text color
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Color(0xFFA81B60), // Custom active thumb color
      // activeTrackColor: Color(0xFFE0A3B3), // Custom active track color
      // inactiveThumbColor: Colors.grey, // Custom inactive thumb color
      // inactiveTrackColor: Colors.grey[300], // Custom inactive track color
    );
  }
}
