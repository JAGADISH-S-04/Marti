import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/screens/notification_screen.dart';
import '../notifications/providers/notification_provider.dart';
import '../notifications/models/notification_type.dart';

/// Notification icon widget for app bar with unread count badge
class NotificationAppBarIcon extends StatefulWidget {
  final Color? iconColor;
  final UserRole? forceUserRole; // Allow manual role specification

  const NotificationAppBarIcon({Key? key, this.iconColor, this.forceUserRole})
      : super(key: key);

  @override
  State<NotificationAppBarIcon> createState() => _NotificationAppBarIconState();
}

class _NotificationAppBarIconState extends State<NotificationAppBarIcon> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().initializeForUser(user.uid);
      });
    }
  }

  Future<void> _showNotifications() async {
    UserRole userRole = UserRole.buyer; // Default

    if (widget.forceUserRole != null) {
      userRole = widget.forceUserRole!;
    } else {
      // Detect current role based on screen context
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentScreen = prefs.getString('current_screen') ?? 'buyer';
        userRole = currentScreen == 'seller' ? UserRole.seller : UserRole.buyer;
      } catch (e) {
        print('Error detecting user role: $e');
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationScreen(userRole: userRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: _showNotifications,
              color: widget.iconColor ??
                  const Color(0xFF2C1810), // Brown color to match theme
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
