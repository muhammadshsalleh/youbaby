import 'package:flutter/material.dart';
import 'package:youbaby/breastfeeding_page.dart';
import 'package:youbaby/feedingOverviewInsights.dart';
import 'package:youbaby/pumping_page.dart';
import 'package:youbaby/bottlefeed_page.dart';

class FeedingTrackerApp extends StatelessWidget {
  final int userId;

  const FeedingTrackerApp({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Feeding Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FeedingTrackerPage(userId: userId),
    );
  }
}

class FeedingTrackerPage extends StatefulWidget {
  final int userId;

  const FeedingTrackerPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FeedingTrackerPageState createState() => _FeedingTrackerPageState();
}

class _FeedingTrackerPageState extends State<FeedingTrackerPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.add(BreastfeedingPage(userId: widget.userId));
    _pages.add(PumpingPage(userId: widget.userId));
    _pages.add(BottleFeedingPage(userId: widget.userId));
    _pages.add(FeedingOverviewInsightsPage(userID: widget.userId));
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Color _getSelectedItemColor(int index) {
    switch (index) {
      case 0:
        return Colors.pink; // Breastfeeding selected color
      case 1:
        return Colors.blue; // Pumping selected color
      case 2:
        return Colors.green; // Bottle Feeding selected color
      case 3:
        return Colors.purple; // Feeding insights selected color
      default:
        return Colors.amber[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Breastfeeding',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.water_drop),
            label: 'Pumping',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.baby_changing_station),
            label: 'Bottle Feeding',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Feeding Insights',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: _getSelectedItemColor(
            _selectedIndex), // Set selected color dynamically
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
