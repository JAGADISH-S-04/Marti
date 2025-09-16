import 'package:flutter/material.dart';
import '../models/notification_type.dart';
import 'notification_screen.dart';

/// Notification screen specifically for sellers
class SellerNotificationScreen extends StatelessWidget {
  const SellerNotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const NotificationScreen(
      userRole: UserRole.seller,
    );
  }
}
