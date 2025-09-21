import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget for displaying an empty state when there are no notifications
class NotificationEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRefresh;

  const NotificationEmptyState({
    Key? key,
    this.title = 'No Notifications',
    this.message = 'You\'re all caught up! No new notifications at the moment.',
    this.icon = Icons.notifications_none,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.openSans(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF2C1810), // Match seller screen color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying loading state
class NotificationLoadingState extends StatelessWidget {
  const NotificationLoadingState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF2C1810)), // Match seller screen color
          ),
          const SizedBox(height: 16),
          Text(
            'Loading notifications...',
            style: GoogleFonts.openSans(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying error state
class NotificationErrorState extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const NotificationErrorState({
    Key? key,
    required this.error,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: GoogleFonts.openSans(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying notification statistics
class NotificationStatsWidget extends StatelessWidget {
  final Map<String, int> stats;

  const NotificationStatsWidget({
    Key? key,
    required this.stats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug: Print the stats to see what's actually available
    print('🔢 STATS DEBUG: Available stats: $stats');

    // Calculate order counts more robustly
    final int orderCount = (stats['order_placed'] ?? 0) +
        (stats['order_confirmed'] ?? 0) +
        (stats['order_shipped'] ?? 0) +
        (stats['order_delivered'] ?? 0) +
        (stats['order_cancelled'] ?? 0);

    // Calculate quotation counts
    final int quotationCount = (stats['quotation_submitted'] ?? 0) +
        (stats['quotation_accepted'] ?? 0) +
        (stats['quotation_rejected'] ?? 0) +
        (stats['quotation_updated'] ?? 0);

    print('🔢 STATS DEBUG: Calculated order count: $orderCount');
    print('🔢 STATS DEBUG: Calculated quotation count: $quotationCount');
    print(
        '🔢 UI DEBUG: Displaying - Total: ${stats['total'] ?? 0}, Unread: ${stats['unread'] ?? 0}, Orders: $orderCount, Quotations: $quotationCount');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2C1810),
            const Color(0xFF1A0F0A)
          ], // Match seller screen colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C1810)
                .withOpacity(0.3), // Match seller screen colors
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Summary',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total',
                  stats['total'] ?? 0,
                  Icons.notifications,
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Unread',
                  stats['unread'] ?? 0,
                  Icons.mark_email_unread,
                  Colors.yellow.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Orders',
                  orderCount,
                  Icons.shopping_bag,
                  Colors.green.shade300,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Quotations',
                  quotationCount,
                  Icons.request_quote,
                  Colors.blue.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: GoogleFonts.openSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget for bulk actions on notifications
class NotificationBulkActionsWidget extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMarkAllAsRead;
  final VoidCallback onDeleteSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  const NotificationBulkActionsWidget({
    Key? key,
    required this.selectedCount,
    required this.onMarkAllAsRead,
    required this.onDeleteSelected,
    required this.onSelectAll,
    required this.onDeselectAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F7), // Match seller screen background
        border: Border(
          bottom: BorderSide(
              color: const Color(0xFF2C1810)
                  .withOpacity(0.2)), // Match seller screen colors
        ),
      ),
      child: Row(
        children: [
          Text(
            '$selectedCount selected',
            style: GoogleFonts.openSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C1810), // Match seller screen colors
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: onSelectAll,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('All'),
            style: TextButton.styleFrom(
              foregroundColor:
                  const Color(0xFF2C1810), // Match seller screen colors
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          TextButton.icon(
            onPressed: onDeselectAll,
            icon: const Icon(Icons.deselect, size: 18),
            label: const Text('None'),
            style: TextButton.styleFrom(
              foregroundColor:
                  const Color(0xFF2C1810), // Match seller screen colors
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onMarkAllAsRead,
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark as read',
            color: const Color(0xFF2C1810), // Match seller screen colors
          ),
          IconButton(
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete selected',
            color: Colors.red.shade600,
          ),
        ],
      ),
    );
  }
}
