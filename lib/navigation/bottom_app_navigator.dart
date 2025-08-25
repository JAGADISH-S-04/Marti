import 'package:arti/screens/buyer_screen.dart';
import 'package:arti/screens/cart_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:arti/screens/seller_screen.dart';
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
    _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialUserType == 'retailer') {
      return const SellerScreen();
    }
    final List<Widget> pages = [
      const BuyerScreen(),
      const CartScreen(),
      const ProfileScreen(),
      Center(child: Text('More Screen')), // Replace with actual screen
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
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
