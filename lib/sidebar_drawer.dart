import 'package:flutter/material.dart';
import 'package:youbaby/profile_page.dart';
import 'package:youbaby/momlibrary_page.dart';
import 'package:youbaby/settings_page.dart';
import 'package:youbaby/charity_page.dart';
import 'package:youbaby/testmap.dart';
import 'home_page.dart';
import 'nearby_clinicpage.dart';
import 'logout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomSidebar extends StatefulWidget {
  final String? parentName;
  final int userID;

  const CustomSidebar({
    Key? key,
    required this.parentName,
    required this.userID,
  }) : super(key: key);

  @override
  _CustomSidebarState createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    fetchUserImage();
  }

  Future<void> fetchUserImage() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('image')
          .eq('id', widget.userID)
          .single();
      
      setState(() {
        imageUrl = response['image'];
      });
    } catch (e) {
      print('Error fetching user image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFFEC9EC0),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFEC9EC0),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40.0,
                    backgroundColor: Color(0xFFEBE0D0),
                    backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                        ? NetworkImage(imageUrl!)
                        : null,
                    child: imageUrl == null || imageUrl!.isEmpty
                        ? Icon(
                            Icons.person,
                            color: Color(0xFFA91B60),
                            size: 50.0,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      '${widget.parentName ?? "Loading..."}',
                      style: const TextStyle(
                        color: Color(0xFFA91B60),
                        fontSize: 24,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.home,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Home'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HomePage(userID: widget.userID)),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.person_2,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ProfilePage(userID: widget.userID)),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.book,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Mom’s Library'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MomLibraryPage(userID: widget.userID)),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.card_giftcard,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Donate Item'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CharityPage(userID: widget.userID)),
                );
              },
            ),
            //nearby clinic page
            ListTile(
              leading: const Icon(
                Icons.local_hospital,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Nearby Clinic'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NearbyClinicPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage(userID: widget.userID)),
                );
              },
            ),
            
            // //location test
            // ListTile(
            //   leading: const Icon(
            //     Icons.location_on,
            //     color: Color(0xFFEBE0D0),
            //   ),
            //   title: const Text('Location (Test)'),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => LocationTestPage()),
            //     );
            //   },
            // ),
            //logout
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Color(0xFFEBE0D0),
              ),
              title: const Text('Logout'),
              onTap: () {
               showLogoutConfirmationDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
