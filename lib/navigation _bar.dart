import 'package:flutter/material.dart';

class BottomNavigationBarWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const BottomNavigationBarWidget({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books),
          label: 'Mom Library',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Community',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Shop',
        ),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: Colors.amber[800],
      onTap: onItemTapped,
    );
  }
}
