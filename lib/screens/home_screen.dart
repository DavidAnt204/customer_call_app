import 'package:flutter/material.dart';
import '../widgets/custom_dialer.dart';
import 'auth_screen.dart';

import 'call_dialer.dart';
import 'call_history.dart';
import 'contacts_screen.dart';
import 'profile.dart';

class HomePage extends StatefulWidget {
  final String email;

  const HomePage({required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<String> _tabTitles = ['Recent', 'Contacts', 'Profile'];
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      CallHistoryPage(),
      ContactListPage(),
      // CallDialerPage(),
      ProfilePage(email: widget.email, onLogout: _logout),
    ];
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen()),
      (route) => false,
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex != 2
          ? AppBar(
              title: Text(
                _tabTitles[_selectedIndex],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.white,
              elevation: 1,
              foregroundColor: Colors.black,
            )
          : null,
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: "Recent"),
          BottomNavigationBarItem(icon: Icon(Icons.recent_actors), label: "Contacts"),
          // BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: "Keypad"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => const DialerBottomSheet(),
        ),
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.dialpad),
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
