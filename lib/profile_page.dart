import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/edit_profilepage.dart';
import 'package:youbaby/momlibrary_page.dart';
import 'package:youbaby/sidebar_drawer.dart';
import 'package:youbaby/settings_page.dart'; // Import Supabase

class ProfilePage extends StatefulWidget {
  final int userID; // User ID passed to the ProfilePage

  const ProfilePage({super.key, required this.userID});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  String? parentName;
  String? email;
  String? babyName;
  String? babyGender;
  DateTime? babyBirthday;
  String? phoneNumber;
  String? role;
  String? imageUrl;

  late AnimationController _controller;
  late Animation<double> _animation;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _fetchUserProfile();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select(
              'parentName, email, babyName, babyGender, babyBirthday, phoneNumber, role, image')
          .eq('id', widget.userID)
          .single();

      setState(() {
        parentName = response['parentName'];
        email = response['email'];
        babyName = response['babyName'];
        babyGender = response['babyGender'];
        babyBirthday = response['babyBirthday'] != null
            ? DateTime.parse(response['babyBirthday'])
            : null;
        phoneNumber = response['phoneNumber'];
        role = response['role'];
        imageUrl = response['image'];
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to format baby age from weeks to months or years
  String formatBabyAge(DateTime? birthday) {
    if (birthday == null) return 'Not set';

    final now = DateTime.now();
    final difference = now.difference(birthday);
    final ageInDays = difference.inDays;

    if (ageInDays < 7) {
      return '$ageInDays day${ageInDays != 1 ? 's' : ''}';
    } else if (ageInDays < 30) {
      final weeks = ageInDays ~/ 7;
      return '$weeks week${weeks != 1 ? 's' : ''}';
    } else if (ageInDays < 365) {
      final months = ageInDays ~/ 30;
      return '$months month${months != 1 ? 's' : ''}';
    } else {
      final years = ageInDays ~/ 365;
      return '$years year${years != 1 ? 's' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFFEBE0D0), // Set text color
            fontSize: 24.0, // Font size
            fontWeight: FontWeight.bold, // Font weight
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.purpleAccent, // Neon shadow
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      // start drawer
      drawer: CustomSidebar(
        parentName: parentName, // Pass parentName from state
        userID: widget.userID, // Pass userID from the widget
      ),

      //end drawer

      body: GestureDetector(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(-1, 0), end: Offset.zero)
                      .animate(_animation),
                  child: Row(
                    children: [
                      FloatingAvatar(imageUrl: imageUrl), // Floating avatar
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parentName ?? 'Loading...', // Display parent's name
                            style: const TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditProfilePage(userID: widget.userID),
                                ),
                              );
                              if (result == true) {
                                _fetchUserProfile(); // Refresh profile data after returning
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA91B60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                              shadowColor: Colors.pinkAccent,
                              elevation: 10,
                            ),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: Color(0xFFEBE0D0), // Set text color
                                shadows: [
                                  Shadow(
                                    blurRadius: 5.0,
                                    color: Colors.purpleAccent, // Neon effect
                                    offset: Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                            
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                _buildSlidingDetailsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon,
      required String text,
      required GestureTapCallback onTap}) {
    return ListTile(
      leading: Icon(
        icon,
        color: Color(0xFFEBE0D0),
      ),
      title: Text(text),
      onTap: onTap,
    );
  }

  Widget _buildSlidingDetailsCard() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(_animation),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Details',
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildDetailRow('Email:', email ?? 'Not set'),
          _buildDetailRow('Role:', role ?? 'Not set'),
          _buildDetailRow('Baby Name:', babyName ?? 'Not set'),
          _buildDetailRow('Baby Gender:', babyGender ?? 'Not set'),
          _buildDetailRow('Baby Age:', formatBabyAge(babyBirthday)),
          _buildDetailRow('Phone Number:', phoneNumber ?? 'Not set'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.0,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingAvatar extends StatelessWidget {
  final String? imageUrl;

  const FloatingAvatar({super.key, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 50.0,
          backgroundColor: const Color(0xFFEBE0D0),
          backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
              ? NetworkImage(imageUrl!)
              : null,
          child: imageUrl == null || imageUrl!.isEmpty
              ? const Icon(
                  Icons.person,
                  size: 50.0,
                  color: Color(0xFFA91B60),
                )
              : null,
        ),
        Positioned(
          bottom: -5,
          right: -5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.pinkAccent,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Colors.pink,
                  blurRadius: 8,
                  offset: Offset(2, 2),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
