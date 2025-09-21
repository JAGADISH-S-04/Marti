import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_filter_widget.dart';
import '../widgets/notification_widgets.dart';
import '../utils/notification_test_utils.dart';

/// Main notification screen for displaying all notifications
class NotificationScreen extends StatefulWidget {
  final UserRole userRole;

  const NotificationScreen({
    Key? key,
    this.userRole = UserRole.buyer,
  }) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Pass the userRole to ensure proper role-based filtering for both notifications and stats
        context
            .read<NotificationProvider>()
            .initializeForUser(user.uid, userRole: widget.userRole);
        _loadNotificationsWithRole(user.uid);
      });
    }
  }

  void _loadNotificationsWithRole(String userId) {
    final provider = context.read<NotificationProvider>();
    provider.loadNotifications(userId,
        refresh: true, userRole: widget.userRole);
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreNotifications();
      }
    });
  }

  void _loadMoreNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final provider = context.read<NotificationProvider>();
      if (provider.hasMoreData && !provider.isLoading) {
        provider.loadNotifications(user.uid, userRole: widget.userRole);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildAuthRequiredScreen();
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF9F9F7), // Match seller screen background
      appBar: _buildAppBar(),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const NotificationLoadingState();
          }

          if (provider.error != null) {
            return NotificationErrorState(
              error: provider.error!,
              onRetry: () =>
                  provider.refresh(user.uid, userRole: widget.userRole),
            );
          }

          return Column(
            children: [
              if (provider.notificationStats.isNotEmpty)
                NotificationStatsWidget(stats: provider.notificationStats),
              _buildSearchBar(),
              if (_isSelectionMode)
                NotificationBulkActionsWidget(
                  selectedCount: _selectedNotificationIds.length,
                  onMarkAllAsRead: _markSelectedAsRead,
                  onDeleteSelected: _deleteSelected,
                  onSelectAll: _selectAll,
                  onDeselectAll: _deselectAll,
                ),
              Expanded(
                child: provider.notifications.isEmpty
                    ? NotificationEmptyState(
                        onRefresh: () => provider.refresh(user.uid,
                            userRole: widget.userRole),
                      )
                    : _buildNotificationList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:
          const Color(0xFF2C1810), // Match seller screen AppBar color
      foregroundColor: Colors.white, // Ensure text and icons are white
      title: Text(
        'Notifications',
        style: GoogleFonts.playfairDisplay(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _exitSelectionMode,
            tooltip: 'Exit selection mode',
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.checklist, color: Colors.white),
            onPressed: _enterSelectionMode,
            tooltip: 'Select notifications',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filter notifications',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, color: Color(0xFF2C1810)),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Color(0xFF2C1810)),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_notifications',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Test Enhanced Notifications'),
                  ],
                ),
              ),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search notifications...',
          hintStyle: GoogleFonts.openSans(color: Colors.grey.shade500),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade500),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: _performSearch,
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    return RefreshIndicator(
      color: const Color(0xFF2C1810), // Match seller screen color scheme
      onRefresh: () => _refreshNotifications(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount:
            provider.notifications.length + (provider.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final notification = provider.notifications[index];
          final isSelected = _selectedNotificationIds.contains(notification.id);

          return GestureDetector(
            onLongPress: () {
              if (!_isSelectionMode) {
                _enterSelectionMode();
              }
              _toggleSelection(notification.id);
            },
            child: Container(
              decoration: _isSelectionMode && isSelected
                  ? BoxDecoration(
                      color: const Color(0xFF2C1810)
                          .withOpacity(0.1), // Match seller screen colors
                      border:
                          Border.all(color: const Color(0xFF2C1810), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: NotificationCard(
                notification: notification,
                showActions: !_isSelectionMode,
                onTap: () => _handleNotificationTap(notification),
                onMarkAsRead: () => _markAsRead(notification.id),
                onDelete: () => _deleteNotification(notification.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.unreadCount == 0) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          onPressed: _markAllAsRead,
          backgroundColor:
              const Color(0xFF2C1810), // Match seller screen color scheme
          foregroundColor: Colors.white,
          icon: const Icon(Icons.mark_email_read),
          label: Text(
            'Mark ${provider.unreadCount} as read',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Widget _buildAuthRequiredScreen() {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF9F9F7), // Match seller screen background
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF2C1810), // Match seller screen AppBar color
        foregroundColor: Colors.white,
        title: Text(
          'Notifications',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
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

  void _showFilterBottomSheet() {
    final provider = context.read<NotificationProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationFilterWidget(
        selectedTypes: provider.typeFilter,
        selectedReadStatus: provider.readFilter,
        selectedPriority: provider.priorityFilter,
        onTypesChanged: (types) => _applyTypeFilter(types),
        onReadStatusChanged: (status) => _applyReadStatusFilter(status),
        onPriorityChanged: (priority) => _applyPriorityFilter(priority),
        onClearFilters: _clearFilters,
      ),
    );
  }

  void _handleMenuAction(String action) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    switch (action) {
      case 'mark_all_read':
        _markAllAsRead();
        break;
      case 'refresh':
        context.read<NotificationProvider>().refresh(user.uid);
        break;
      case 'test_notifications':
        NotificationTestUtils.showTestDialog(context);
        break;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (_isSelectionMode) {
      _toggleSelection(notification.id);
      return;
    }

    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Handle navigation based on notification type
    _navigateToNotificationDetails(notification);
  }

  void _navigateToNotificationDetails(NotificationModel notification) {
    // TODO: Implement navigation based on notification type
    // For example:
    // - Order notifications -> Navigate to order details
    // - Quotation notifications -> Navigate to quotation details
    // - Chat notifications -> Navigate to chat
    // - Product notifications -> Navigate to product details

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to ${notification.type.value} details'),
        backgroundColor:
            const Color(0xFF2C1810), // Match seller screen color scheme
      ),
    );
  }

  void _performSearch(String query) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<NotificationProvider>().searchNotifications(user.uid, query);
    }
  }

  void _applyTypeFilter(List<NotificationType>? types) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<NotificationProvider>().applyFilters(
            user.uid,
            types: types,
          );
    }
  }

  void _applyReadStatusFilter(bool? status) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<NotificationProvider>().applyFilters(
            user.uid,
            isRead: status,
          );
    }
  }

  void _applyPriorityFilter(NotificationPriority? priority) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<NotificationProvider>().applyFilters(
            user.uid,
            priority: priority,
          );
    }
  }

  void _clearFilters() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<NotificationProvider>().clearFilters(user.uid);
    }
  }

  void _markAsRead(String notificationId) {
    context.read<NotificationProvider>().markAsRead(notificationId);
  }

  void _markAllAsRead() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<NotificationProvider>().markAllAsRead(user.uid);
    }
  }

  void _deleteNotification(String notificationId) {
    context.read<NotificationProvider>().deleteNotification(notificationId);
  }

  Future<void> _refreshNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await context
          .read<NotificationProvider>()
          .refresh(user.uid, userRole: widget.userRole);
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNotificationIds.clear();
    });
  }

  void _toggleSelection(String notificationId) {
    setState(() {
      if (_selectedNotificationIds.contains(notificationId)) {
        _selectedNotificationIds.remove(notificationId);
      } else {
        _selectedNotificationIds.add(notificationId);
      }
    });
  }

  void _selectAll() {
    final provider = context.read<NotificationProvider>();
    setState(() {
      _selectedNotificationIds.clear();
      _selectedNotificationIds.addAll(
        provider.notifications.map((n) => n.id),
      );
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedNotificationIds.clear();
    });
  }

  void _markSelectedAsRead() {
    if (_selectedNotificationIds.isNotEmpty) {
      context
          .read<NotificationProvider>()
          .markMultipleAsRead(_selectedNotificationIds.toList());
      _exitSelectionMode();
    }
  }

  void _deleteSelected() {
    if (_selectedNotificationIds.isNotEmpty) {
      context
          .read<NotificationProvider>()
          .deleteMultipleNotifications(_selectedNotificationIds.toList());
      _exitSelectionMode();
    }
  }
}
