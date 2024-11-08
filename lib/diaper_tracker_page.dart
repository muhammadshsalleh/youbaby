import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'diaper_entry.dart';  
import 'diaper_insights.dart'; 
import 'diaper_history.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase


class DiaperTrackerPage extends StatefulWidget {
  final int userID;

  const DiaperTrackerPage({super.key, required this.userID});

  @override
  _DiaperTrackerPageState createState() => _DiaperTrackerPageState();
}

class _DiaperTrackerPageState extends State<DiaperTrackerPage> {
  int _selectedIndex = 0;
  
  late final List<Widget> _pages; 
  
  @override
  void initState() {
    super.initState();
    
    _pages = [
      DiaperEntryPage(userID: widget.userID),
      DiaperInsightsPage(
        userID: widget.userID,
        navigateToNewEntry: () => _onItemTapped(0), // Redirects to New Entry
        
        ),
        DiaperHistoryPage(userID: widget.userID),
    ];
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
       title: const Text(
          'Diaper Tracker',
          style: TextStyle(
            color: Color(0xFFF6F2FF),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'New Entry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFA91B60),
        onTap: _onItemTapped,
      ),
    );
  }
}