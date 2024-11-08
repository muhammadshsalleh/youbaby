import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:youbaby/Baby_development.dart';
import 'package:youbaby/babytracker_page.dart';
import 'package:youbaby/checklist.dart';
import 'package:youbaby/checklist_list.dart';
import 'package:youbaby/community_page.dart';
import 'package:youbaby/diaper_tracker_page.dart';
import 'package:youbaby/growthTrackerNavigation.dart';
import 'package:youbaby/login_page.dart';
import 'package:youbaby/name_librarypage.dart';
import 'package:youbaby/shopPage.dart';
import 'package:youbaby/read_page.dart';
import 'package:youbaby/signup_page.dart';
import 'package:youbaby/sleep_tracker_page.dart';
import 'welcome_page.dart'; // Import your WelcomePage
import 'home_page.dart'; // Import your HomePage
import 'momlibrary_page.dart'; // Import your MomLibraryPage
//import 'package:flutter_inappwebview/flutter_inappwebview.dart'; //for play video maybe
import 'package:supabase_flutter/supabase_flutter.dart'; //for DB

const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings(
        'app_icon'); // 'app_icon' should match the name of your icon file (without the file extension)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rzkzhuwabmqqmpnqzqmn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ6a3podXdhYm1xcW1wbnF6cW1uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjQyODk5MDMsImV4cCI6MjAzOTg2NTkwM30.7PddrnclQy1bP6SjSEoKBwmTSdsUZZQ1o5VePpOGEq8',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Youbaby App',
      theme: ThemeData(
        primarySwatch:
            Colors.pink, // You can customize this to match your colors
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      //supportedLocales: L10n.all,
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomePage(), // Route to WelcomePage
        //'/home': (context) => HomePage(userID: 'ayam',), // Route to HomePage
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        // Add other routes here
        //'/momLibrary': (context) => MomLibraryPage(userID: null,),
        //'/read': (context) => ReadPage(),
        '/namelibrary': (context) => NameLibraryPage(),
        // '/checklist': (context) =>
        //     ChecklistPage(), // Define the checklist route
        //'/checklists': (context) => const ChecklistListPage(),
        '/baby-development': (context) => const BabyDevelopmentPage(),
        // '/community': (context) =>
        //     CommunityPage(), // Add the CommunityPage route
        '/clinic': (context) => const ShopPage(),
        //'/baby-tracker': (context) => const BabyTrackerPage(),
        //'/sleep-tracker': (context) => SleepTrackerPage(),
        // '/feeding-tracker': (context) => FeedingTrackerPage(),
        // '/diaper-tracker': (context) => DiaperTrackerPage(),
        //'/growth-tracker': (context) => GrowthTrackerApp(),
      },
      // Uncomment the following line if you want to handle undefined routes
      // onUnknownRoute: (settings) => MaterialPageRoute(builder: (context) => UnknownPage()),
    );
  }
}
