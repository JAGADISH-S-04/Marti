import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/cart_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:arti/screens/craft_it/craft_it_screen.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isRetailer = false;
  
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
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if user is a retailer
        final retailerDoc = await FirebaseFirestore.instance
            .collection('retailers')
            .doc(user.uid)
            .get();

        if (retailerDoc.exists) {
          // User is a retailer, redirect to seller screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const SellerScreen(),
            ),
            (route) => false,
          );
          return;
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking user type: $e');
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

    final List<Widget> pages = [
      const BuyerScreen(),
      const CraftItScreen(),
      const ProfileScreen(),
      const Center(child: Text('More Screen')),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryBrown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.design_services), label: 'Craft It'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}