import 'package:flutter/material.dart';
import 'package:youbaby/growthHistory.dart';
import 'package:youbaby/growthInsightsPage.dart';
import 'package:youbaby/growthTrackerPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GrowthTrackerApp extends StatelessWidget {
  final int userId;
  const GrowthTrackerApp({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Remove MaterialApp since it should be wrapped at a higher level
    return GrowthTrackerHome(userId: userId);
  }
}

class GrowthTrackerHome extends StatefulWidget {
  final int userId;

  const GrowthTrackerHome({super.key, required this.userId});

  @override
  State<GrowthTrackerHome> createState() => _GrowthTrackerHomeState();
}

class _GrowthTrackerHomeState extends State<GrowthTrackerHome> {
  int _selectedIndex = 0;
  String? babyName;
  DateTime? babyBirthday;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadBabyInfo();
  }

  Future<void> _loadBabyInfo() async {
    try {
      final userResponse = await supabase
          .from('users')
          .select('babyName, babyBirthday')
          .eq('id', widget.userId)
          .single();
      
      setState(() {
        babyName = userResponse['babyName'];
        if (userResponse['babyBirthday'] != null) {
          babyBirthday = DateTime.parse(userResponse['babyBirthday']);
        }
      });
    } catch (e) {
      debugPrint('Error loading baby info: $e');
    }
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return '${babyName ?? "Baby"}\'s Growth';
      case 1:
        return 'Growth History';
      case 2:
        return 'Growth Insights';
      default:
        return 'Growth Tracker';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      GrowthTrackerPage(userId: widget.userId),
      GrowthHistoryPage(userId: widget.userId),
      GrowthInsightsPage(userId: widget.userId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: const Color(0xFFA91B60),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFFA91B60),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_weight),
            label: 'Measure',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}