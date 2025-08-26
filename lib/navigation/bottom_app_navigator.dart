import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/cart_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    // Set initial index based on user type
    _selectedIndex = 0; // Always start with home/buyer screen
  }

  @override
  Widget build(BuildContext context) {
    // Remove this problematic condition that returns BuyerScreen directly
    // if (widget.initialUserType == 'customer') {
    //   return const BuyerScreen();
    // }

    final List<Widget> pages = [
      const BuyerScreen(),
      const CartScreen(),
      const ProfileScreen(),
      const Center(child: Text('More Screen')), // Replace with actual screen
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}