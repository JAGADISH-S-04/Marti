import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen> {
  final Color primaryBrown = const Color.fromARGB(255, 93, 64, 55);
  final Color backgroundBrown = const Color.fromARGB(255, 245, 240, 235);

  bool _useSimpleQuery = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: backgroundBrown,
        appBar: AppBar(
          backgroundColor: primaryBrown,
          title: Text(
            'Notifications',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: const Center(
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

    return Scaffold(
      backgroundColor: backgroundBrown,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        title: Text(
          'Notifications',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _useSimpleQuery
            ? FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: currentUser.uid)
                .orderBy('createdAt', descending: true)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: currentUser.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryBrown),
                  const SizedBox(height: 16),
                  const Text('Loading notifications...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            // Switch to simple query if index error
            final errorString = snapshot.error.toString();
            if ((errorString.contains('failed-precondition') ||
                    errorString.contains('index')) &&
                !_useSimpleQuery) {
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
                    const SizedBox(height: 16),
                    const Text('Switching to fallback mode...'),
                  ],
                ),
              );
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading notifications',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _useSimpleQuery
                        ? 'Using simplified view (index building)'
                        : 'Error: $errorString',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _useSimpleQuery = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrown,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You\'ll receive updates about your orders and quotations here.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {});
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
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
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final notification = doc.data() as Map<String, dynamic>;

              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final bool isRead = notification['isRead'] ?? false;
    final String type = notification['type'] ?? '';
    final Timestamp? timestamp = notification['createdAt'] as Timestamp?;

    Color cardColor;
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'quotation_accepted':
        cardColor = Colors.green.shade50;
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'order_completed':
        cardColor = Colors.purple.shade50;
        iconData = Icons.done_all;
        iconColor = Colors.purple;
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 4,
      color: isRead ? Colors.white : cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRead ? BorderSide.none : BorderSide(color: iconColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!isRead) {
            NotificationService.markAsRead(notification['id']);
          }
          _handleNotificationTap(notification);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
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
              const SizedBox(width: 12),
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
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              color: isRead ? Colors.grey.shade700 : primaryBrown,
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
                    const SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
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
  }

  String _formatTimestamp(Timestamp timestamp) {
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
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Handle tap actions, e.g., navigate to order details screen if requestId exists
  }

  Future<void> _markAllAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final notifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'updatedAt': Timestamp.now(),
      });
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications marked as read'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
