import 'package:flutter/material.dart';
import 'package:youbaby/checklist_list.dart';

class ChecklistPage extends StatelessWidget {
  final int userId; // Add this line to accept userId from HomePage

  const ChecklistPage({super.key, required this.userId}); // Update constructor to accept userId

  @override
  Widget build(BuildContext context) {
    // Print the userId in the console for debugging
    print("User ID: $userId");

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'List of Checklists',
          style: TextStyle(
            color: Color(0xFFEBE0D0), // Set text color
            fontSize: 24.0, // Font size
            fontWeight: FontWeight.bold, // Font weight
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFf5e5ed), Color(0xFFebccdb)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChecklistListPage(userId: userId),
                      ),
                    );
                  },
                  child: const Card(
                    elevation: 4.0,
                    color: Color(0xFFffffff), // Background color
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_box, // Icon for Checklist
                            color: Color(0xFFA91B60), // Icon color
                            size: 64.0,
                          ),
                          SizedBox(height: 5), // Adjust the height as needed
                          Text(
                            'Checklist',
                            style: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA91B60), // Text color
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/baby-development');
                  },
                  child: const Card(
                    elevation: 4.0,
                    color: Color(0xFFffffff), // Background color
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons
                                .baby_changing_station, // Icon for Baby Development Tools
                            color: Color(0xFFA91B60), // Icon color
                            size: 64.0,
                          ),
                          SizedBox(height: 5), // Adjust the height as needed
                          Text(
                            'Baby Development Tools',
                            style: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA91B60), // Text color
                            ),
                          ),
                        ],
                      ),
                    ),
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
