import 'package:flutter/material.dart';
import '../models/notification_type.dart';
import 'notification_screen.dart';

/// Notification screen specifically for buyers
class BuyerNotificationScreen extends StatelessWidget {
  const BuyerNotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const NotificationScreen(
      userRole: UserRole.buyer,
    );
  }
}
