// File: lib/screens/main_seller_scaffold.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arti/services/locale_service.dart';
import 'package:arti/widgets/l10n_language_selector.dart';
import 'package:provider/provider.dart';
import 'package:arti/screens/seller_analytics_screen.dart';
import 'package:arti/screens/seller_screen.dart';
import 'package:arti/screens/profile_screen.dart';
import 'package:arti/screens/Seller_search_screen.dart';
import 'package:arti/screens/forum/forum_screen.dart';

import 'package:arti/screens/faq/retailer_faq_screen.dart';

class MainSellerScaffold extends StatefulWidget {
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
  State<MainSellerScaffold> createState() => _MainSellerScaffoldState();
}

class _MainSellerScaffoldState extends State<MainSellerScaffold> {
  LocaleService? _localeService;

  @override
  void initState() {
    super.initState();
    // Initialize after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _localeService = Provider.of<LocaleService>(context, listen: false);
      _localeService!.addListener(_onLanguageChanged);
    });
  }

  @override
  void dispose() {
    _localeService?.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to update translate icon
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      // --- Reusable AppBar ---
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F7),
        elevation: 0,
        // This ensures the drawer icon is the correct color
        iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
        centerTitle: false,
        actions: [
          Consumer<LocaleService>(
            builder: (context, localeService, child) {
              return IconButton(
                tooltip: 'Translate',
                icon: Icon(
                  localeService.currentLocale.languageCode == 'en'
                      ? Icons.translate
                      : Icons.g_translate,
                  color: const Color(0xFF2C1810),
                ),
                onPressed: () => _showLanguageSelector(context),
              );
            },
          ),
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
      drawer: widget.drawer,

      // --- Screen Content Goes Here ---
      body: widget.body,

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
            icon: Icons.forum,
            label: 'Forum',
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
            icon: Icons.analytics,
            label: 'Analytics',
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

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Colors.brown),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select your preferred language. Text on this page will be translated for you.',
                      style: TextStyle(fontSize: 12, color: Colors.brown),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const L10nLanguageSelector(
                primaryColor: Color(0xFF2C1810),
                accentColor: Color(0xFFD4AF37),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = widget.currentIndex == index;
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
