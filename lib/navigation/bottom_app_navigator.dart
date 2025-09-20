import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:arti/screens/craft_it/craft_it_screen.dart';
import 'package:arti/screens/more_screen.dart';
import 'package:arti/services/storage_service.dart';
import 'package:arti/widgets/notification_app_bar_icon.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomAppNavigator extends StatefulWidget {
  final String? initialUserType;

  const BottomAppNavigator({Key? key, this.initialUserType}) : super(key: key);

  static Route route({String? initialUserType}) {
    return MaterialPageRoute(
      builder: (_) => BottomAppNavigator(initialUserType: initialUserType),
    );
  }

  @override
  _BottomAppNavigatorState createState() => _BottomAppNavigatorState();
}

class _BottomAppNavigatorState extends State<BottomAppNavigator> {
  late int _selectedIndex;
  bool _isLoading = true;

  // Using the seed color
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    try {
      // Save that user is currently on buyer screen
      await StorageService.saveCurrentScreen('buyer');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error saving current screen: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryBrown),
        ),
      );
    }

    final List<String> titles = [
      'Arti Marketplace',
      'Craft It',
      'Profile',
      'More',
    ];

    final List<Widget> pages = [
      const BuyerScreen(),
      const CraftItScreen(),
      const ProfileScreen(),
      const MoreScreen(),
    ];

    // Show app bar only for screens that don't have their own app bars
    // Buyer screen (index 0) has its own custom top container
    // CraftIt screen (index 1) has its own app bar with tabs
    final bool showAppBar = _selectedIndex != 0 && _selectedIndex != 1;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(
                titles[_selectedIndex],
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: primaryBrown,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                const NotificationAppBarIcon(),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryBrown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.design_services), label: 'Craft It'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
