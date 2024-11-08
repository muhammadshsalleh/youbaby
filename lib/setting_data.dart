import 'package:flutter/material.dart';

class DataManagementPage extends StatefulWidget {
  @override
  _DataManagementPageState createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Data Management Settings", 
        style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          )),
        backgroundColor: Color(0xFFA81B60),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Text(
            'Data Management',
            style: TextStyle(
              fontSize: 18,
              color: const Color(0xFFA81B60),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16), 

          
        ],
      ),
    );
  }
}
