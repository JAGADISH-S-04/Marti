import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color lightBrown = const Color.fromARGB(255, 139, 98, 87);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);

  bool _useSimpleQuery = false;

  @override
  void initState() {
    super.initState();
    print('NotificationsScreen: initState called');
  }

  @override
  void dispose() {
    print('NotificationsScreen: dispose called');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('NotificationsScreen: build called');

    final currentUser = FirebaseAuth.instance.currentUser;
    print('NotificationsScreen: currentUser = ${currentUser?.uid}');

    if (currentUser == null) {
      print('NotificationsScreen: No current user, showing login message');
      return Scaffold(
        backgroundColor: backgroundBrown,
        appBar: AppBar(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          title: Text('Notifications'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Please log in to view notifications'),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        print('NotificationsScreen: Back button pressed');
        return true;
      },
      child: Scaffold(
        backgroundColor: backgroundBrown,
        appBar: AppBar(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          title: Text(
            'Notifications',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.mark_email_read),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _useSimpleQuery
              ? NotificationService.getUserNotificationsSimple(currentUser.uid)
              : NotificationService.getUserNotifications(currentUser.uid),
          builder: (context, snapshot) {
            print(
                'NotificationsScreen: StreamBuilder state = ${snapshot.connectionState}');
            print('NotificationsScreen: Has error = ${snapshot.hasError}');
            print('NotificationsScreen: Error = ${snapshot.error}');
            print('NotificationsScreen: Has data = ${snapshot.hasData}');
            print(
                'NotificationsScreen: Data count = ${snapshot.data?.docs.length ?? 0}');

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: primaryBrown),
                    SizedBox(height: 16),
                    Text('Loading notifications...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              print('NotificationsScreen: Stream error = ${snapshot.error}');

              // Check if it's an index error and switch to simple query
              if (snapshot.error.toString().contains('failed-precondition') ||
                  snapshot.error.toString().contains('index')) {
                if (!_useSimpleQuery) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _useSimpleQuery = true;
                    });
                  });
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryBrown),
                        SizedBox(height: 16),
                        Text('Switching to fallback mode...'),
                      ],
                    ),
                  );
                }
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Error loading notifications',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _useSimpleQuery
                          ? 'Using simplified view (index building)'
                          : 'Error: ${snapshot.error}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        print('NotificationsScreen: Retry button pressed');
                        setState(() {
                          _useSimpleQuery = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrown,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data?.docs ?? [];
            print(
                'NotificationsScreen: Building with ${notifications.length} notifications');

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You\'ll receive updates about your quotations here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        print('NotificationsScreen: Refresh button pressed');
                        setState(() {});
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrown,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                try {
                  final doc = notifications[index];
                  final notification = doc.data() as Map<String, dynamic>;

                  return _buildNotificationCard(notification);
                } catch (e) {
                  print(
                      'NotificationsScreen: Error building notification card at index $index: $e');
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Error loading notification',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    try {
      final isRead = notification['isRead'] ?? false;
      final type = notification['type'] ?? '';
      final timestamp = notification['createdAt'] as Timestamp?;

      Color cardColor;
      IconData iconData;
      Color iconColor;

      switch (type) {
        case 'quotation_accepted':
          cardColor = Colors.green.shade50;
          iconData = Icons.check_circle;
          iconColor = Colors.green;
          break;
        case 'quotation_rejected':
          cardColor = Colors.red.shade50;
          iconData = Icons.cancel;
          iconColor = Colors.red;
          break;
        default:
          cardColor = Colors.blue.shade50;
          iconData = Icons.info;
          iconColor = Colors.blue;
      }

      return Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: isRead ? 1 : 4,
        color: isRead ? Colors.white : cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isRead
              ? BorderSide.none
              : BorderSide(color: iconColor.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            try {
              print('NotificationsScreen: Notification tapped');
              if (!isRead) {
                NotificationService.markAsRead(notification['id']);
              }
              _handleNotificationTap(notification);
            } catch (e) {
              print('NotificationsScreen: Error handling tap: $e');
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'Notification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    isRead ? FontWeight.w500 : FontWeight.bold,
                                color: isRead
                                    ? Colors.grey.shade700
                                    : primaryBrown,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: iconColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        notification['message'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      if (timestamp != null) ...[
                        SizedBox(height: 8),
                        Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      // Show quotation details if available
                      if (notification['data'] != null &&
                          type == 'quotation_rejected') ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Your quote: ₹${notification['data']['yourQuotedPrice'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Delivery: ${notification['data']['yourDeliveryTime'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('NotificationsScreen: Error in _buildNotificationCard: $e');
      return Card(
        margin: EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Error displaying notification: $e',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    try {
      final now = DateTime.now();
      final date = timestamp.toDate();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      print('NotificationsScreen: Error formatting timestamp: $e');
      return 'Unknown time';
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    try {
      final type = notification['type'];
      final data = notification['data'] as Map<String, dynamic>?;

      if (data != null && data['requestId'] != null) {
        // Navigate to request details or show more info
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(notification['title'] ?? 'Notification Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification['message'] ?? ''),
                if (type == 'quotation_rejected' &&
                    data['yourQuotedPrice'] != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your quotation details:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text('Price: ₹${data['yourQuotedPrice']}'),
                        Text('Delivery Time: ${data['yourDeliveryTime']}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('NotificationsScreen: Error handling notification tap: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening notification details'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      print('NotificationsScreen: _markAllAsRead called');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('NotificationsScreen: No current user for marking as read');
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      print(
          'NotificationsScreen: Found ${notifications.docs.length} unread notifications');

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'updatedAt': Timestamp.now(),
        });
      }

      await batch.commit();
      print('NotificationsScreen: All notifications marked as read');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('NotificationsScreen: Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating notifications'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
