import 'package:flutter/material.dart';
import 'package:youbaby/growthTrackerNavigation.dart';
import 'package:youbaby/growthTrackerPage.dart';
import 'package:youbaby/sleep_tracker_page.dart';
import 'package:youbaby/feeding_tracker.dart';
import 'package:youbaby/diaper_tracker_page.dart';


class BabyTrackerPage extends StatelessWidget {
  final int userID;

  const BabyTrackerPage({super.key, required this.userID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Baby Tracker',
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
          child: GridView.count(
            crossAxisCount: 2, // 2 items per row
            crossAxisSpacing: 16.0, // Horizontal space between cards
            mainAxisSpacing: 16.0, // Vertical space between cards
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // builder: (context) => SleepTrackerPage(),
                      builder: (context) => SleepTrackerPage(userID: userID),
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
                          Icons.nights_stay, // Icon for Sleep Tracker
                          color: Color(0xFFA91B60), // Icon color
                          size: 48.0,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Sleep Tracker',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA91B60), // Text color
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // builder: (context) => SleepTrackerPage(),
                      builder: (context) => FeedingTrackerPage(userId: userID),
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
                          Icons.local_dining, // Icon for Feeding Tracker
                          color: Color(0xFFA91B60), // Icon color
                          size: 48.0,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Feeding Tracker',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA91B60), // Text color
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigator.pushNamed(context, '/diaper-tracker');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiaperTrackerPage(userID: userID),
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
                          Icons
                              .baby_changing_station, // Icon for Diaper Tracker
                          color: Color(0xFFA91B60), // Icon color
                          size: 48.0,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Diaper Tracker',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA91B60), // Text color
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GrowthTrackerApp(userId: userID),
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
                          Icons.height, // Icon for Growth Tracker
                          color: Color(0xFFA91B60), // Icon color
                          size: 48.0,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Growth Tracker',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA91B60), // Text color
                          ),
                        ),
                      ],
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

