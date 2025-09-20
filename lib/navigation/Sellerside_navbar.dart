// File: lib/screens/main_seller_scaffold.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arti/screens/seller_analytics_screen.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:arti/screens/Seller_search_screen.dart';
import 'package:arti/screens/forum/forum_screen.dart';

import 'package:arti/screens/faq/retailer_faq_screen.dart';

class MainSellerScaffold extends StatelessWidget {
  /// The main content of the screen.
  final Widget body;

  /// The index of the currently selected item in the bottom navigation bar.
  /// 0 = Home, 1 = Messages, 2 = Analytics
  final int? currentIndex;

  /// An optional drawer widget for the screen.
  final Widget? drawer;

  const MainSellerScaffold({
    Key? key,
    required this.body,
    this.currentIndex, // Default to Home
    this.drawer,
  }) : super(key: key);

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF9F9F7),
    // --- Reusable AppBar ---
    appBar: AppBar(
      backgroundColor: const Color(0xFFF9F9F7),
      elevation: 0,
      automaticallyImplyLeading: false, // This removes the back button
      // This ensures the drawer icon is the correct color
      iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
      centerTitle: false,
      leading: drawer != null ? Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF2C1810)),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ) : null, // Only show drawer icon if drawer is provided
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFF2C1810)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SellerSearchScreen()),
            );
          },
        ),
        IconButton(
          icon:
              const Icon(Icons.notifications_none, color: Color(0xFF2C1810)),
          onPressed: () {/* Handle notifications */},
        ),
        IconButton(
          icon: const Icon(Icons.person, color: Color(0xFF2C1810)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
      ],
    ),
    // --- Use the drawer passed from the parent screen ---
    drawer: drawer,

    // --- Screen Content Goes Here ---
    body: body,

    // --- Reusable Bottom Navigation Bar ---
    bottomNavigationBar: _buildBottomNavigationBar(context),
  );
}

  // --- Bottom Navigation Bar Builder ---
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.home,
            label: 'Home',
            index: 0,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SellerScreen()),
              );
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.help_outline,
            label: 'FAQ',
            index: 1,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ForumScreen()),
              );
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.forum,
            label: 'Forum',
            index: 2,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const SellerAnalyticsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2C1810) : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF2C1810) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
