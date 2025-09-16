import 'package:cloud_firestore/cloud_firestore.dart';

class DeadlineUtils {
  /// Format deadline timestamp to display string
  static String formatDeadline(dynamic deadline) {
    if (deadline == null) return 'Not set';

    DateTime deadlineDate;
    if (deadline is Timestamp) {
      deadlineDate = deadline.toDate();
    } else if (deadline is DateTime) {
      deadlineDate = deadline;
    } else if (deadline is String && deadline.isNotEmpty) {
      // Handle legacy string deadlines
      return deadline;
    } else {
      return 'Not set';
    }

    return '${deadlineDate.day}/${deadlineDate.month}/${deadlineDate.year}';
  }

  /// Get remaining time until deadline
  static String getTimeRemaining(dynamic deadline) {
    if (deadline == null) return '';

    DateTime deadlineDate;
    if (deadline is Timestamp) {
      deadlineDate = deadline.toDate();
    } else if (deadline is DateTime) {
      deadlineDate = deadline;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = deadlineDate.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
    } else {
      return 'Expiring soon';
    }
  }

  /// Check if deadline has passed
  static bool isDeadlinePassed(dynamic deadline) {
    if (deadline == null) return false;

    DateTime deadlineDate;
    if (deadline is Timestamp) {
      deadlineDate = deadline.toDate();
    } else if (deadline is DateTime) {
      deadlineDate = deadline;
    } else {
      return false;
    }

    return DateTime.now().isAfter(deadlineDate);
  }

  /// Get deadline status color
  static String getDeadlineStatus(dynamic deadline) {
    if (deadline == null) return 'no_deadline';

    DateTime deadlineDate;
    if (deadline is Timestamp) {
      deadlineDate = deadline.toDate();
    } else if (deadline is DateTime) {
      deadlineDate = deadline;
    } else {
      return 'no_deadline';
    }

    final now = DateTime.now();
    final difference = deadlineDate.difference(now);

    if (difference.isNegative) {
      return 'expired';
    } else if (difference.inHours < 24) {
      return 'urgent';
    } else if (difference.inDays < 3) {
      return 'warning';
    } else {
      return 'normal';
    }
  }

  /// Format deadline with time remaining
  static String formatDeadlineWithTime(dynamic deadline) {
    final formattedDate = formatDeadline(deadline);
    final timeRemaining = getTimeRemaining(deadline);

    if (formattedDate == 'Not set') return formattedDate;
    if (timeRemaining.isEmpty) return formattedDate;

    return '$formattedDate ($timeRemaining)';
  }
}
