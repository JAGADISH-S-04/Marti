import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification_type.dart';

/// Widget for filtering notifications
class NotificationFilterWidget extends StatefulWidget {
  final List<NotificationType>? selectedTypes;
  final bool? selectedReadStatus;
  final NotificationPriority? selectedPriority;
  final Function(List<NotificationType>?) onTypesChanged;
  final Function(bool?) onReadStatusChanged;
  final Function(NotificationPriority?) onPriorityChanged;
  final VoidCallback onClearFilters;

  const NotificationFilterWidget({
    Key? key,
    this.selectedTypes,
    this.selectedReadStatus,
    this.selectedPriority,
    required this.onTypesChanged,
    required this.onReadStatusChanged,
    required this.onPriorityChanged,
    required this.onClearFilters,
  }) : super(key: key);

  @override
  State<NotificationFilterWidget> createState() =>
      _NotificationFilterWidgetState();
}

class _NotificationFilterWidgetState extends State<NotificationFilterWidget> {
  List<NotificationType> _selectedTypes = [];
  bool? _selectedReadStatus;
  NotificationPriority? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _selectedTypes = widget.selectedTypes ?? [];
    _selectedReadStatus = widget.selectedReadStatus;
    _selectedPriority = widget.selectedPriority;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Filter Notifications',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTypes.clear();
                    _selectedReadStatus = null;
                    _selectedPriority = null;
                  });
                  widget.onClearFilters();
                },
                child: Text(
                  'Clear All',
                  style: GoogleFonts.openSans(
                    color: Colors.brown.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Read Status Filter
          Text(
            'Read Status',
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(
                label: 'All',
                isSelected: _selectedReadStatus == null,
                onTap: () {
                  setState(() {
                    _selectedReadStatus = null;
                  });
                  widget.onReadStatusChanged(null);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Unread',
                isSelected: _selectedReadStatus == false,
                onTap: () {
                  setState(() {
                    _selectedReadStatus = false;
                  });
                  widget.onReadStatusChanged(false);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Read',
                isSelected: _selectedReadStatus == true,
                onTap: () {
                  setState(() {
                    _selectedReadStatus = true;
                  });
                  widget.onReadStatusChanged(true);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority Filter
          Text(
            'Priority',
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(
                label: 'All',
                isSelected: _selectedPriority == null,
                onTap: () {
                  setState(() {
                    _selectedPriority = null;
                  });
                  widget.onPriorityChanged(null);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Urgent',
                isSelected: _selectedPriority == NotificationPriority.urgent,
                color: Colors.red,
                onTap: () {
                  setState(() {
                    _selectedPriority = NotificationPriority.urgent;
                  });
                  widget.onPriorityChanged(NotificationPriority.urgent);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'High',
                isSelected: _selectedPriority == NotificationPriority.high,
                color: Colors.orange,
                onTap: () {
                  setState(() {
                    _selectedPriority = NotificationPriority.high;
                  });
                  widget.onPriorityChanged(NotificationPriority.high);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Medium',
                isSelected: _selectedPriority == NotificationPriority.medium,
                color: Colors.blue,
                onTap: () {
                  setState(() {
                    _selectedPriority = NotificationPriority.medium;
                  });
                  widget.onPriorityChanged(NotificationPriority.medium);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type Filter
          Text(
            'Notification Types',
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeFilter(
                  'Orders',
                  [
                    NotificationType.orderPlaced,
                    NotificationType.orderConfirmed,
                    NotificationType.orderShipped,
                    NotificationType.orderDelivered,
                    NotificationType.orderCancelled,
                    NotificationType.orderRefunded,
                  ],
                  Icons.shopping_bag,
                  Colors.green),
              _buildTypeFilter(
                  'Quotations',
                  [
                    NotificationType.quotationSubmitted,
                    NotificationType.quotationAccepted,
                    NotificationType.quotationRejected,
                    NotificationType.quotationUpdated,
                  ],
                  Icons.request_quote,
                  Colors.blue),
              _buildTypeFilter(
                  'Payments',
                  [
                    NotificationType.paymentReceived,
                    NotificationType.paymentFailed,
                    NotificationType.paymentRefunded,
                  ],
                  Icons.payment,
                  Colors.purple),
              _buildTypeFilter(
                  'Chat',
                  [
                    NotificationType.newMessage,
                    NotificationType.chatStarted,
                  ],
                  Icons.chat,
                  Colors.teal),
              _buildTypeFilter(
                  'Products',
                  [
                    NotificationType.productListed,
                    NotificationType.productSold,
                    NotificationType.productLowStock,
                  ],
                  Icons.inventory,
                  Colors.orange),
              _buildTypeFilter(
                  'System',
                  [
                    NotificationType.systemUpdate,
                    NotificationType.maintenance,
                    NotificationType.general,
                  ],
                  Icons.settings,
                  Colors.grey),
            ],
          ),
          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Apply Filters',
                style: GoogleFonts.openSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? Colors.brown.shade600)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (color ?? Colors.brown.shade600)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.openSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilter(
    String label,
    List<NotificationType> types,
    IconData icon,
    Color color,
  ) {
    final isSelected = types.any((type) => _selectedTypes.contains(type));

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            // Remove all types in this category
            _selectedTypes.removeWhere((type) => types.contains(type));
          } else {
            // Add all types in this category
            for (final type in types) {
              if (!_selectedTypes.contains(type)) {
                _selectedTypes.add(type);
              }
            }
          }
        });
        widget.onTypesChanged(_selectedTypes.isEmpty ? null : _selectedTypes);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.openSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
