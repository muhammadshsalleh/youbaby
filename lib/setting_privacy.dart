import 'package:flutter/material.dart';
import 'package:youbaby/settings_page.dart';

// Sample placeholder pages for each settings option.
class PrivacySecurityPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Privacy & Security Settings", 
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          )),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: ListView(
        children: [
          // Profile Settings Tile
          SettingsTile(
            icon: Icons.person,
            title: 'Setting 1',
            onTap: () {
              // Handle the tap
            },
          ), //settingsTile
          Divider(),

          SettingsTile(
            icon: Icons.person,
            title: 'Setting 2',
            onTap: () {
              // Handle the tap
            },
          ), //settingsTile
          Divider(),

          SettingsTile(
            icon: Icons.person,
            title: 'Setting 3',
            onTap: () {
              // Handle the tap
            },
          ), //settingsTile
          Divider(),

        ],
      ),
    );
  }
}