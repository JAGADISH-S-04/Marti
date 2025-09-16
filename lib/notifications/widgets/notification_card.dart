import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';

/// Widget for displaying a single notification item
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onDelete;
  final bool showActions;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
    this.onDelete,
    this.showActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead
              ? Colors.grey.shade300
              : Colors.brown.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildNotificationIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 16,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    color: Colors.brown.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.timeAgo,
                            style: GoogleFonts.openSans(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showActions) _buildActionButtons(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notification.message,
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (notification.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      notification.imageUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (_shouldShowExtraInfo()) ...[
                  const SizedBox(height: 8),
                  _buildExtraInfo(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.orderPlaced:
      case NotificationType.orderConfirmed:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
        iconData = Icons.shopping_bag;
        iconColor = Colors.green;
        break;
      case NotificationType.orderCancelled:
      case NotificationType.orderRefunded:
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case NotificationType.quotationSubmitted:
      case NotificationType.quotationAccepted:
      case NotificationType.quotationUpdated:
        iconData = Icons.request_quote;
        iconColor = Colors.blue;
        break;
      case NotificationType.quotationRejected:
        iconData = Icons.thumb_down;
        iconColor = Colors.orange;
        break;
      case NotificationType.paymentReceived:
      case NotificationType.paymentRefunded:
        iconData = Icons.payment;
        iconColor = Colors.green;
        break;
      case NotificationType.paymentFailed:
        iconData = Icons.payment;
        iconColor = Colors.red;
        break;
      case NotificationType.newMessage:
      case NotificationType.chatStarted:
        iconData = Icons.chat;
        iconColor = Colors.purple;
        break;
      case NotificationType.productListed:
      case NotificationType.productSold:
        iconData = Icons.inventory;
        iconColor = Colors.teal;
        break;
      case NotificationType.productLowStock:
        iconData = Icons.warning;
        iconColor = Colors.orange;
        break;
      case NotificationType.systemUpdate:
      case NotificationType.maintenance:
        iconData = Icons.system_update;
        iconColor = Colors.grey;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.brown;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  Widget _buildActionButtons() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Colors.grey.shade600,
        size: 18,
      ),
      itemBuilder: (context) => [
        if (!notification.isRead)
          PopupMenuItem(
            value: 'mark_read',
            child: Row(
              children: [
                Icon(Icons.mark_email_read,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text('Mark as read'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red.shade600),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red.shade600)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'mark_read':
            onMarkAsRead?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
    );
  }

  Color _getPriorityColor() {
    switch (notification.priority) {
      case NotificationPriority.urgent:
        return Colors.red;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.medium:
        return Colors.blue;
      case NotificationPriority.low:
        return Colors.green;
    }
  }

  bool _shouldShowExtraInfo() {
    return notification.data.isNotEmpty &&
        (notification.data.containsKey('orderId') ||
            notification.data.containsKey('quotationId') ||
            notification.data.containsKey('transactionId') ||
            notification.data.containsKey('products') ||
            notification.data.containsKey('itemCount') ||
            notification.data.containsKey('amount'));
  }

  Widget _buildExtraInfo() {
    final data = notification.data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order details
        if (data.containsKey('orderId')) ...[
          _buildInfoChip('Order', data['orderId'], Icons.shopping_bag),
          const SizedBox(height: 4),
        ],

        // Quotation details
        if (data.containsKey('quotationId')) ...[
          _buildInfoChip('Quotation', data['quotationId'], Icons.request_quote),
          const SizedBox(height: 4),
        ],

        // Transaction details
        if (data.containsKey('transactionId')) ...[
          _buildInfoChip('Transaction', data['transactionId'], Icons.payment),
          const SizedBox(height: 4),
        ],

        // Order summary information
        if (data.containsKey('itemCount') || data.containsKey('amount')) ...[
          Row(
            children: [
              if (data.containsKey('itemCount'))
                _buildInfoChip(
                    'Items', '${data['itemCount']}', Icons.inventory_2),
              if (data.containsKey('itemCount') && data.containsKey('amount'))
                const SizedBox(width: 8),
              if (data.containsKey('amount'))
                _buildInfoChip(
                    'Amount',
                    '₹${(data['amount'] as num).toStringAsFixed(2)}',
                    Icons.currency_rupee),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Product list for orders
        if (data.containsKey('products')) ...[
          const SizedBox(height: 4),
          _buildProductList(data['products'] as List<dynamic>),
        ],
      ],
    );
  }

  Widget _buildProductList(List<dynamic> products) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, size: 16, color: Colors.brown.shade600),
              const SizedBox(width: 6),
              Text(
                'Order Details',
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...products.take(3).map<Widget>((product) {
            final productMap = product as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${productMap['productName'] ?? 'Product'} × ${productMap['quantity'] ?? 1}',
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        color: Colors.brown.shade600,
                      ),
                    ),
                  ),
                  if (productMap['price'] != null)
                    Text(
                      '₹${(productMap['price'] as num).toStringAsFixed(2)}',
                      style: GoogleFonts.openSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.brown.shade700,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          if (products.length > 3) ...[
            const SizedBox(height: 4),
            Text(
              '... and ${products.length - 3} more items',
              style: GoogleFonts.openSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.brown.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.brown.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.brown.shade600),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: Colors.brown.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
