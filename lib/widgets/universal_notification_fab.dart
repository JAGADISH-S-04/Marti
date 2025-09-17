import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications/screens/notification_screen.dart';
import '../notifications/providers/notification_provider.dart';

/// Universal notification floating action button that can be used anywhere in the app
class UniversalNotificationFAB extends StatefulWidget {
  final Widget child;
  final bool showFAB;

  const UniversalNotificationFAB({
    Key? key,
    required this.child,
    this.showFAB = true,
  }) : super(key: key);

  @override
  State<UniversalNotificationFAB> createState() =>
      _UniversalNotificationFABState();
}

class _UniversalNotificationFABState extends State<UniversalNotificationFAB> {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showFAB)
          Positioned(
            bottom: 16,
            right: 16,
            child: Consumer<NotificationProvider>(
              builder: (context, notificationProvider, child) {
                final unreadCount = notificationProvider.unreadCount;

                return FloatingActionButton(
                  heroTag: "universal_notification_fab",
                  onPressed: () => _openNotifications(context),
                  backgroundColor: const Color(0xFF2C1810),
                  foregroundColor: Colors.white,
                  elevation: 8,
                  child: Stack(
                    children: [
                      const Icon(
                        Icons.notifications,
                        size: 24,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
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
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _openNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Color(0xFF2C1810),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1810),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            // Notification content
            const Expanded(
              child: NotificationScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper widget for screens that want to show the notification FAB
class ScreenWithNotificationFAB extends StatelessWidget {
  final Widget child;
  final bool showFAB;

  const ScreenWithNotificationFAB({
    Key? key,
    required this.child,
    this.showFAB = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UniversalNotificationFAB(
      showFAB: showFAB,
      child: child,
    );
  }
}
