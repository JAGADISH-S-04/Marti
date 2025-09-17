import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import '../utils/user_role_detector.dart';

/// Provider for managing notification state throughout the app
class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository = NotificationRepository();

  // State variables
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  Map<String, int> _notificationStats = {};

  // Filters and pagination
  List<NotificationType>? _typeFilter;
  bool? _readFilter;
  NotificationPriority? _priorityFilter;
  String _searchQuery = '';
  bool _hasMoreData = true;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  Map<String, int> get notificationStats => _notificationStats;
  bool get hasMoreData => _hasMoreData;

  List<NotificationType>? get typeFilter => _typeFilter;
  bool? get readFilter => _readFilter;
  NotificationPriority? get priorityFilter => _priorityFilter;
  String get searchQuery => _searchQuery;

  /// Initialize the provider for a specific user with role-based filtering
  Future<void> initializeForUser(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      // Get user role for proper notification filtering
      final userRole = await UserRoleDetector.getUserRoleForScreen();
      print(
          '🔐 Initializing notifications for user $userId as ${userRole.value}');

      // Load initial notifications with role filtering
      await loadNotifications(userId, userRole: userRole);

      // Load notification stats with role filtering
      await loadNotificationStats(userId, userRole: userRole);

      // Setup real-time listeners with role filtering
      _setupUnreadCountListener(userId, userRole: userRole);
    } catch (e) {
      _setError('Failed to initialize notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load notifications for a user with role-based filtering
  Future<void> loadNotifications(String userId,
      {bool refresh = false, UserRole? userRole}) async {
    try {
      if (refresh) {
        _notifications.clear();
        _hasMoreData = true;
      }

      if (!_hasMoreData) return;

      _setLoading(true);
      _clearError();

      // Get user role if not provided
      final targetRole =
          userRole ?? await UserRoleDetector.getUserRoleForScreen();
      print('📂 Loading notifications for ${targetRole.value} role');

      final newNotifications = await _repository.getUserNotifications(
        userId: userId,
        userRole: targetRole, // CRITICAL: Filter by user role
        limit: 20,
        types: _typeFilter,
        isRead: _readFilter,
        priority: _priorityFilter,
      );

      if (refresh) {
        _notifications = newNotifications;
      } else {
        _notifications.addAll(newNotifications);
      }

      _hasMoreData = newNotifications.length == 20;
      print(
          '📊 Loaded ${newNotifications.length} notifications for ${targetRole.value}');
    } catch (e) {
      _setError('Failed to load notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Search notifications with role filtering
  Future<void> searchNotifications(String userId, String query) async {
    try {
      _setLoading(true);
      _clearError();
      _searchQuery = query;

      if (query.isEmpty) {
        await loadNotifications(userId, refresh: true);
        return;
      }

      // Get user role for search filtering
      final userRole = await UserRoleDetector.getUserRoleForScreen();

      final searchResults = await _repository.searchNotifications(
        userId: userId,
        searchQuery: query,
        types: _typeFilter,
        userRole: userRole, // Add role filtering to search
      );

      _notifications = searchResults;
      _hasMoreData = false; // No pagination for search results
    } catch (e) {
      _setError('Failed to search notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Apply filters
  Future<void> applyFilters(
    String userId, {
    List<NotificationType>? types,
    bool? isRead,
    NotificationPriority? priority,
  }) async {
    _typeFilter = types;
    _readFilter = isRead;
    _priorityFilter = priority;

    await loadNotifications(userId, refresh: true);
  }

  /// Clear all filters
  Future<void> clearFilters(String userId) async {
    _typeFilter = null;
    _readFilter = null;
    _priorityFilter = null;
    _searchQuery = '';

    await loadNotifications(userId, refresh: true);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        if (_unreadCount > 0) {
          _unreadCount--;
        }
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to mark notification as read: $e');
    }
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    try {
      await _repository.markMultipleAsRead(notificationIds);

      // Update local state
      int updatedCount = 0;
      for (int i = 0; i < _notifications.length; i++) {
        if (notificationIds.contains(_notifications[i].id) &&
            !_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
          updatedCount++;
        }
      }

      _unreadCount = (_unreadCount - updatedCount).clamp(0, _unreadCount);
      notifyListeners();
    } catch (e) {
      _setError('Failed to mark notifications as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _repository.markAllAsRead(userId);

      // Update local state
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }

      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _setError('Failed to mark all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final wasUnread = !_notifications[index].isRead;
        _notifications.removeAt(index);
        if (wasUnread && _unreadCount > 0) {
          _unreadCount--;
        }
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to delete notification: $e');
    }
  }

  /// Delete multiple notifications
  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    try {
      await _repository.deleteMultipleNotifications(notificationIds);

      // Update local state
      int deletedUnreadCount = 0;
      _notifications.removeWhere((notification) {
        if (notificationIds.contains(notification.id)) {
          if (!notification.isRead) {
            deletedUnreadCount++;
          }
          return true;
        }
        return false;
      });

      _unreadCount = (_unreadCount - deletedUnreadCount).clamp(0, _unreadCount);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete notifications: $e');
    }
  }

  /// Load notification statistics with role filtering
  Future<void> loadNotificationStats(String userId,
      {UserRole? userRole}) async {
    try {
      // Get user role if not provided
      final targetRole =
          userRole ?? await UserRoleDetector.getUserRoleForScreen();

      _notificationStats =
          await _repository.getNotificationStats(userId, userRole: targetRole);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load notification stats: $e');
    }
  }

  /// Get notifications by type
  Future<List<NotificationModel>> getNotificationsByType(
    String userId,
    NotificationType type, {
    bool? isRead,
  }) async {
    try {
      return await _repository.getNotificationsByType(
        userId: userId,
        type: type,
        isRead: isRead,
      );
    } catch (e) {
      _setError('Failed to get notifications by type: $e');
      return [];
    }
  }

  /// Get notifications by priority
  Future<List<NotificationModel>> getNotificationsByPriority(
    String userId,
    NotificationPriority priority, {
    bool? isRead,
  }) async {
    try {
      return await _repository.getNotificationsByPriority(
        userId: userId,
        priority: priority,
        isRead: isRead,
      );
    } catch (e) {
      _setError('Failed to get notifications by priority: $e');
      return [];
    }
  }

  /// Setup real-time listener for unread count with role filtering
  void _setupUnreadCountListener(String userId, {UserRole? userRole}) {
    // Get user role if not provided (use async method)
    if (userRole != null) {
      _repository
          .getUnreadNotificationCountStream(userId, userRole: userRole)
          .listen(
        (count) {
          _unreadCount = count;
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to listen to unread count: $error');
        },
      );
    } else {
      // Fallback to get role asynchronously
      UserRoleDetector.getUserRoleForScreen().then((role) {
        _repository
            .getUnreadNotificationCountStream(userId, userRole: role)
            .listen(
          (count) {
            _unreadCount = count;
            notifyListeners();
          },
          onError: (error) {
            _setError('Failed to listen to unread count: $error');
          },
        );
      }).catchError((error) {
        _setError('Failed to setup unread count listener: $error');
      });
    }
  }

  /// Send order notification (convenience method)
  Future<void> sendOrderNotification({
    required String userId,
    required NotificationType type,
    required String orderId,
    required String customerName,
    required String sellerName,
    required String productName,
    required double totalAmount,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      await NotificationService.sendOrderNotification(
        userId: userId,
        type: type,
        orderId: orderId,
        customerName: customerName,
        sellerName: sellerName,
        productName: productName,
        totalAmount: totalAmount,
        targetRole: targetRole,
        priority: priority,
        additionalData: additionalData,
      );
    } catch (e) {
      _setError('Failed to send order notification: $e');
    }
  }

  /// Send quotation notification (convenience method)
  Future<void> sendQuotationNotification({
    required String userId,
    required NotificationType type,
    required String quotationId,
    required String customerName,
    required String artisanName,
    required String requestTitle,
    required double quotedPrice,
    UserRole targetRole = UserRole.buyer,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      await NotificationService.sendQuotationNotification(
        userId: userId,
        type: type,
        quotationId: quotationId,
        customerName: customerName,
        artisanName: artisanName,
        requestTitle: requestTitle,
        quotedPrice: quotedPrice,
        targetRole: targetRole,
        priority: priority,
        additionalData: additionalData,
      );
    } catch (e) {
      _setError('Failed to send quotation notification: $e');
    }
  }

  /// Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh notifications
  Future<void> refresh(String userId, {UserRole? userRole}) async {
    await loadNotifications(userId, refresh: true, userRole: userRole);
    await loadNotificationStats(userId, userRole: userRole);
  }

  /// Reset provider state
  void reset() {
    _notifications.clear();
    _isLoading = false;
    _error = null;
    _unreadCount = 0;
    _notificationStats.clear();
    _typeFilter = null;
    _readFilter = null;
    _priorityFilter = null;
    _searchQuery = '';
    _hasMoreData = true;
    notifyListeners();
  }
}
