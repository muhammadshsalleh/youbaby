import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/babytracker_page.dart';
import 'package:youbaby/checklist_list.dart';
import 'package:youbaby/community_page.dart';
import 'package:youbaby/shopPage.dart';
import 'package:youbaby/profile_page.dart';
import 'package:youbaby/momlibrary_page.dart';
import 'package:youbaby/name_librarypage.dart';
import 'package:youbaby/checklist.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youbaby/read_page.dart';
import 'package:youbaby/settings_page.dart';
import 'package:youbaby/sidebar_drawer.dart';
import 'package:youbaby/charity_page.dart';
import 'nearby_clinicpage.dart';
import 'notification_page.dart';
import 'album_page.dart';
import 'dart:async'; // For Timer
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  final int userID;
  final bool requestLocation;

  // const HomePage({required this.userID});
  const HomePage({required this.userID, this.requestLocation = false});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2;
  String? parentName;
  int? userID;
  List<dynamic> latestArticles = []; // List to hold latest articles
  bool _showAllTools = false;

  // Two different PageControllers
  late PageController _imagePageController;
  late PageController _articlePageController;

  // Two different timers for image and article carousels
  int _currentImagePage = 0;
  int _currentArticlePage = 0;
  late Timer _imageTimer;
  late Timer _articleTimer;

  List<Map<String, dynamic>> get toolCards => [
    {
      'title': 'Checklists',
      'icon': Icons.checklist,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistPage(userId: userID!)),
        );
      },
    },
    {
      'title': 'Name Library',
      'icon': Icons.library_books,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NameLibraryPage()),
        );
      },
    },
    {
      'title': 'Baby Tracker',
      'icon': Icons.baby_changing_station,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BabyTrackerPage(userID: userID!)),
        );
      },
    },
    {
      'title': 'Mom\'s Library',
      'icon': Icons.library_books,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MomLibraryPage(userID: userID!)),
        );
      },
    },
    {
      'title': 'Baby Album',
      'icon': Icons.photo_album,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BabyAlbumPage(userID: userID!)),
        );
      },
    },
    {
      'title': 'Donate Item',
      'icon': Icons.card_giftcard,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  CharityPage(userID: widget.userID)),
        );
      },
    },
    {
      'title': 'Nearby Clinics',
      'icon': Icons.local_hospital,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NearbyClinicPage()),
        );
      },
    },
    {
      'title': 'Community',
      'icon': Icons.forum,
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  CommunityPage(userID: userID!)),
        );
      },
    },
  ];

  Future<bool> _onWillPop() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Are you sure?'),
            content: Text('Do you want to exit the application?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  void initState() {
    super.initState();
    userID = widget.userID;
    _fetchParentName();
    _fetchLatestArticles(); // Fetch latest articles when the page loads

    // Initialize PageControllers
    _imagePageController = PageController(initialPage: _currentImagePage);
    _articlePageController = PageController(initialPage: _currentArticlePage);

    // Start auto-sliding for both carousels
    _startImageAutoSlide();
    _startArticleAutoSlide();

    // location
    if (widget.requestLocation) {
      _requestLocationPermission();
    }
  }

  @override
  void dispose() {
    // Dispose both controllers and timers
    _imagePageController.dispose();
    _articlePageController.dispose();
    _imageTimer.cancel();
    _articleTimer.cancel();
    super.dispose();
  }

  // Function for auto-sliding image carousel
  void _startImageAutoSlide() {
    _imageTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      int totalPages = 5; // Assume you have 5 images
      _currentImagePage = (_currentImagePage + 1) % totalPages;

      _imagePageController.animateToPage(
        _currentImagePage,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    });
  }

  // Function for auto-sliding article carousel
  void _startArticleAutoSlide() {
    _articleTimer = Timer.periodic(Duration(seconds: 7), (timer) {
      int totalPages = latestArticles.length;
      if (totalPages > 0) {
        _currentArticlePage = (_currentArticlePage + 1) % totalPages;

        _articlePageController.animateToPage(
          _currentArticlePage,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    });
  }

  Future<void> _fetchParentName() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('parentName, id')
          .eq('id', widget.userID)
          .single();

      setState(() {
        parentName = response['parentName'];
        userID = response['id'];
      });
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error fetching parent name: $e')),
      // );
    }
  }

  Future<void> _fetchLatestArticles() async {
    try {
      final response = await Supabase.instance.client
          .from('article2')
          .select('*')
          .order('created_at', ascending: false)
          .limit(5);
      // print('Response data: ${response}');

      setState(() {
        latestArticles = response as List<dynamic>;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching latest articles: $e')),
      );
    }
  }

  //location function

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permissions are permanently denied. Please enable them in your device settings.'),
        ),
      );
      return;
    }

    await _getCurrentLocationAndStore();
  }

  Future<void> _getCurrentLocationAndStore() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        await Supabase.instance.client.from('users').update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'city': place.locality ?? 'Unknown',
          'state': place.administrativeArea ?? 'Unknown',
          'country': place.country ?? 'Unknown',
          // 'district': place.subAdministrativeArea ?? 'Unknown',  // Add this line for county
          
        }).eq('id', widget.userID);

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Location updated successfully')),
        // );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error updating location: $e')),
      // );
      print(e);
    }
  }
  //end location function

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProfilePage(userID: userID!)),
          );
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MomLibraryPage(userID: userID!)),
          );
          break;
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage(userID: userID!)),
          );
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CommunityPage(userID: userID!)),
          );
          break;
        case 4:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShopPage()),
          );
          break;
      }
    });
  }

  Widget _buildToolCard(BuildContext context, String title, IconData icon,
    Color color, VoidCallback onTap) {
    double screenWidth = MediaQuery.of(context).size.width;
    int numCards = 4; // Adjust this based on the number of cards

    // Calculate the maximum width needed to fit all cards in one line
    double cardWidth = screenWidth / numCards - 16;
    double totalCardWidth = numCards * (cardWidth + 12.0);

    if (totalCardWidth > screenWidth) {
      // If all cards don't fit in one line, display in a 2x2 grid
      numCards = 2;
      cardWidth = screenWidth / 2 - 16;
    }

    return Container(
      width: cardWidth,
      child: Card(
        elevation: 5, // Add elevation for shadow effect
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFf2f2ff), // First color
                  Color(0xFFEC9EC0), // Second color
                  Color(0xFFA91B60), // Third color
                ],
                stops: [
                  0.0,
                  0.5,
                  1.0
                ], // Optional: stops where each color starts
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    icon,
                    size: cardWidth * 0.3,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: cardWidth * 0.13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildToolsGrid() {
    List<Map<String, dynamic>> visibleTools = 
        _showAllTools ? toolCards : toolCards.take(4).toList();

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8.0),
          children: visibleTools.map((tool) => _buildToolCard(
            context,
            tool['title'],
            tool['icon'],
            const Color(0xFFEC9EC0),
            tool['onTap'],
          )).toList(),
        ),
        if (toolCards.length > 4)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showAllTools = !_showAllTools;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showAllTools ? 'Show Less' : 'See More',
                    style: const TextStyle(
                      color: Color(0xFFA91B60),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _showAllTools ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFFA91B60),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Home',
              style: TextStyle(
                color: Color(0xFFEBE0D0),
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFFA91B60),
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                color: const Color(0xFFEBE0D0),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                color: const Color(0xFFEBE0D0),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NotificationPage()),
                  );
                },
              ),
            ],
          ),
          //drawer for sidebar , not replaced with sidebar.dart yet
          drawer: CustomSidebar(
            // Use the CustomSidebar widget here
            parentName: parentName,
            userID: userID!,
          ),
          //end drawer - sidebar

         body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFf5e5ed), Color(0xFFebccdb)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.9, 1.0],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10.0),
                // Image carousel
                Container(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: PageView(
                    controller: _imagePageController,
                    children: <Widget>[
                        Image.asset(
                          'assets/Photo.jpg',
                          fit: BoxFit.contain,
                        ),
                        Image.asset(
                          'assets/Photo 2.jpg',
                          fit: BoxFit.contain,
                        ),
                        Image.asset(
                          'assets/Photo 3.jpg',
                          fit: BoxFit.contain,
                        ),
                        Image.asset(
                          'assets/Photo 4.jpg',
                          fit: BoxFit.contain,
                        ),
                        Image.asset(
                          'assets/Photo 5.jpg',
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  // Modified tools grid
                  _buildToolsGrid(),
                  // const SizedBox(height: 10.0),

                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Latest Articles',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA91B60),
                      ),
                    ),
                  ),
                  // Latest Articles Carousel
                  Container(
                    height: 230.0, // Adjust as needed
                    child: PageView.builder(
                      controller: _articlePageController,
                      itemCount: latestArticles.length,
                      itemBuilder: (context, index) {
                        final article = latestArticles[index];
                        final publishDate = article['created_at'];
                        final formattedDate = publishDate != null
                            ? DateFormat('dd/MM/yyyy')
                                .format(DateTime.parse(publishDate))
                            : 'No Date';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          elevation: 5,
                          color: const Color(0xFFffffff),
                          shadowColor: const Color(0xFFEC9EC0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReadPage(
                                    articleId: article['id'],
                                    userId: widget.userID,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article['title'] ?? 'No Title',
                                    style: const TextStyle(
                                      color: Color(0xFF333333),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Text(
                                    article['detail'] != null
                                        ? article['detail']
                                                .substring(0, 150) +
                                            '...'
                                        : 'No Content',
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: const Color(0xFFA91B60),
            selectedItemColor: const Color(0xFFA91B60),
            unselectedItemColor: const Color(0xFFEC9EC0),
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'You',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.book),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.forum),
                label: 'Community',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shop),
                label: 'Shop',
              ),
            ],
          ),
        ));
  }
}
