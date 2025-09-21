import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/forum_models.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_service.dart';
import '../notifications/services/notification_service.dart';
import '../notifications/models/notification_type.dart';

/// Forum service for artisan/seller community discussions
/// This service handles questions, answers, and knowledge sharing among sellers
class ForumService {
  static final ForumService _instance = ForumService._internal();
  factory ForumService() => _instance;
  ForumService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirestoreService _firestoreService = FirestoreService();

  // Collection names
  static const String forumPostsCollection = 'forum_posts';
  static const String forumCommentsCollection = 'forum_comments';
  static const String forumVotesCollection = 'forum_votes';

  // Debug method to check user profile - handles both UID types
  Future<Map<String, dynamic>?> debugUserProfile() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return null;
      }

      print('DEBUG: Checking user profile for ID: ${currentUser.uid}');

      // Strategy 1: Check directly in retailers collection first (exact UID - Type 2)
      final retailerDoc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc(currentUser.uid)
          .get();
      if (retailerDoc.exists) {
        final retailerData = retailerDoc.data()!;

        // Add the isRetailer flag manually
        retailerData['isRetailer'] = true;
        retailerData['userType'] = 'retailer';
        return retailerData;
      }

      // Strategy 2: Check retailers collection with _retailer suffix (Type 1)
      final retailerWithSuffixDoc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc('${currentUser.uid}_retailer')
          .get();
      if (retailerWithSuffixDoc.exists) {
        final retailerData = retailerWithSuffixDoc.data()!;

        // Add the isRetailer flag manually
        retailerData['isRetailer'] = true;
        retailerData['userType'] = 'retailer';
        return retailerData;
      }

      // Strategy 3: Check if this is a customer (they can't access forum)
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(currentUser.uid)
          .get();
      if (customerDoc.exists) {
        final customerData = customerDoc.data()!;

        // Add the isRetailer flag manually
        customerData['isRetailer'] = false;
        customerData['userType'] = 'customer';
        return customerData;
      }

      // Strategy 4: Use FirestoreService as fallback
      final userProfile =
          await _firestoreService.checkUserExists(currentUser.uid);

      if (userProfile != null) {
        // Check if this user profile indicates they're a retailer
        if (userProfile['isRetailer'] == true ||
            userProfile['userType'] == 'retailer') {
          return userProfile;
        }
      }

      print('DEBUG: No user profile found in any collection');
      return null;
    } catch (e) {
      print('DEBUG: Error checking user profile: $e');
      return null;
    }
  }

  // Fix existing posts with wrong authorName
  Future<void> fixExistingPostsAuthorNames() async {
    try {
      print('DEBUG: Starting to fix existing posts...');

      // Get all posts
      final postsSnapshot =
          await _firestore.collection(forumPostsCollection).get();

      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final authorId = postData['authorId'];
        final currentAuthorName = postData['authorName'];

        print(
            'DEBUG: Post ${postDoc.id} - authorId: $authorId, currentAuthorName: $currentAuthorName');

        if (currentAuthorName == null ||
            currentAuthorName == '' ||
            currentAuthorName == 'Unknown Seller') {
          // This post needs fixing
          print('DEBUG: Fixing post ${postDoc.id}...');

          // Get the correct author name for this authorId
          Map<String, dynamic>? authorProfile;

          // Try direct UID lookup
          final retailerDoc =
              await _firestore.collection('retailers').doc(authorId).get();
          if (retailerDoc.exists) {
            authorProfile = retailerDoc.data()!;
          } else {
            // Try with suffix
            final retailerWithSuffixDoc = await _firestore
                .collection('retailers')
                .doc('${authorId}_retailer')
                .get();
            if (retailerWithSuffixDoc.exists) {
              authorProfile = retailerWithSuffixDoc.data()!;
            }
          }

          if (authorProfile != null) {
            final correctAuthorName = authorProfile['fullName'] ??
                authorProfile['name'] ??
                authorProfile['displayName'] ??
                authorProfile['username'] ??
                'Unknown Seller';

            print(
                'DEBUG: Updating post ${postDoc.id} authorName from "$currentAuthorName" to "$correctAuthorName"');

            // Update the post
            await postDoc.reference.update({'authorName': correctAuthorName});
          }
        }
      }

      print('DEBUG: Finished fixing existing posts');
    } catch (e) {
      print('DEBUG: Error fixing existing posts: $e');
    }
  }

  // Create a new forum post
  Future<String> createPost({
    required String title,
    required String content,
    required PostCategory category,
    required PostPriority priority,
    List<String> tags = const [],
    File? imageFile,
    File? voiceFile,
    String? transcription,
    Duration? voiceDuration,
    String? detectedLanguage,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile using our debug method (which checks collections directly)
      final userProfile = await debugUserProfile();

      if (userProfile == null) {
        throw Exception(
            'User profile not found. Please ensure you are registered as a seller.');
      }

      // Since forum is seller-only, verify user is a retailer
      if (userProfile['isRetailer'] != true) {
        throw Exception('Forum access is restricted to sellers only.');
      }

      // Get the author name from profile
      final authorName = userProfile['fullName'] ??
          userProfile['name'] ??
          userProfile['displayName'] ??
          userProfile['username'] ??
          'Unknown Seller';

      String? imageUrl;
      String? voiceUrl;

      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await _uploadForumImage(imageFile, currentUser.uid);
      }

      // Upload voice file if provided
      if (voiceFile != null) {
        voiceUrl = await _uploadForumVoice(voiceFile, currentUser.uid);
      }

      final now = DateTime.now();
      final postData = {
        'authorId': currentUser.uid,
        'authorName': authorName, // Use our debugged authorName variable
        'authorType': 'seller', // Since forum is seller-only
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'voiceUrl': voiceUrl,
        'transcription': transcription,
        'voiceDurationSeconds': voiceDuration?.inSeconds,
        'detectedLanguage': detectedLanguage,
        'timestamp': Timestamp.fromDate(now),
        'lastActivity': Timestamp.fromDate(now),
        'viewCount': 0,
        'commentCount': 0,
        'tags': tags,
        'isResolved': false,
        'resolvedByUserId': null,
        'resolvedAt': null,
        'category': category.toString().split('.').last,
        'priority': priority.toString().split('.').last,
      };

      final docRef =
          await _firestore.collection(forumPostsCollection).add(postData);

      return docRef.id;
    } catch (e) {
      print('Error creating forum post: $e');
      throw Exception('Failed to create post: $e');
    }
  }

  // Get forum posts with filtering and sorting
  Stream<List<ForumPost>> getForumPosts({
    PostCategory? category,
    bool? isResolved,
    String? searchQuery,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    try {
      // Check if user is authenticated before querying
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return Stream.value([]);
      }

      Query query = _firestore.collection(forumPostsCollection);

      // Apply filters
      if (category != null) {
        query = query.where('category',
            isEqualTo: category.toString().split('.').last);
        print('DEBUG: Filtering by category: $category');
      }

      if (isResolved != null) {
        query = query.where('isResolved', isEqualTo: isResolved);
      }

      // Order by last activity (most recent first)
      query = query.orderBy('lastActivity', descending: true);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      return query.snapshots().map((snapshot) {
        List<ForumPost> posts = snapshot.docs.map((doc) {
          return ForumPost.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();

        // Apply text search filter if provided
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final searchLower = searchQuery.toLowerCase();
          posts = posts.where((post) {
            return post.title.toLowerCase().contains(searchLower) ||
                post.content.toLowerCase().contains(searchLower) ||
                post.tags.any((tag) => tag.toLowerCase().contains(searchLower));
          }).toList();
        }

        return posts;
      });
    } catch (e) {
      print('Error getting forum posts: $e');
      throw Exception('Failed to get posts: $e');
    }
  }

  // Get a specific forum post by ID
  Future<ForumPost?> getPostById(String postId) async {
    try {
      final doc =
          await _firestore.collection(forumPostsCollection).doc(postId).get();

      if (!doc.exists) {
        return null;
      }

      return ForumPost.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      print('Error getting post by ID: $e');
      return null;
    }
  }

  // Get a specific forum post by ID as a stream (real-time updates)
  Stream<ForumPost?> getPostByIdStream(String postId) {
    try {
      return _firestore
          .collection(forumPostsCollection)
          .doc(postId)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return ForumPost.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      });
    } catch (e) {
      print('Error getting post stream by ID: $e');
      return Stream.value(null);
    }
  }

  // Clear viewed posts for current user (call on app start or logout)
  Future<void> clearViewedPosts() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final viewedPostsKey = 'viewed_posts_${currentUser.uid}';
      await prefs.remove(viewedPostsKey);
    } catch (e) {
      print('Error clearing viewed posts: $e');
    }
  }

  // Increment post view count (only once per session per user)
  Future<void> incrementViewCount(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final viewedPostsKey = 'viewed_posts_${currentUser.uid}';
      final viewedPosts = prefs.getStringList(viewedPostsKey) ?? [];

      // Only increment if this post hasn't been viewed in this session
      if (!viewedPosts.contains(postId)) {
        await _firestore.collection(forumPostsCollection).doc(postId).update({
          'viewCount': FieldValue.increment(1),
        });

        // Mark as viewed in current session
        viewedPosts.add(postId);
        await prefs.setStringList(viewedPostsKey, viewedPosts);
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  // Mark post as resolved (only by post author)
  Future<void> markPostAsResolved(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // First, get the post to check if current user is the author
      final postDoc =
          await _firestore.collection(forumPostsCollection).doc(postId).get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data()!;
      if (postData['authorId'] != currentUser.uid) {
        throw Exception('Only the post author can mark their post as resolved');
      }

      // Update the post to mark as resolved
      await _firestore.collection(forumPostsCollection).doc(postId).update({
        'isResolved': true,
        'resolvedByUserId': currentUser.uid,
        'resolvedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error marking post as resolved: $e');
      throw Exception('Failed to mark post as resolved: $e');
    }
  }

  // Add a comment to a forum post
  Future<String> addComment({
    required String postId,
    required String content,
    File? imageFile,
    File? voiceFile,
    String? transcription,
    Duration? voiceDuration,
    String? detectedLanguage,
    String? parentCommentId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print('DEBUG Comment: Current user ID: ${currentUser.uid}');

      // Get user profile using the robust debug method
      final userProfile = await debugUserProfile();

      if (userProfile == null) {
        throw Exception(
            'User profile not found. Please ensure you are properly registered as a seller. Check your account setup.');
      }

      // Since forum is seller-only, verify user is a retailer
      if (userProfile['isRetailer'] != true) {
        throw Exception(
            'Forum access is restricted to sellers only. Please contact support if you believe this is an error.');
      }

      String? imageUrl;
      String? voiceUrl;

      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await _uploadForumImage(imageFile, currentUser.uid);
      }

      // Upload voice file if provided
      if (voiceFile != null) {
        voiceUrl = await _uploadForumVoice(voiceFile, currentUser.uid);
      }

      final commentData = {
        'postId': postId,
        'authorId': currentUser.uid,
        'authorName': userProfile['fullName'] ??
            userProfile['displayName'] ??
            userProfile['name'] ??
            'Unknown Seller',
        'authorType': 'seller', // Since forum is seller-only
        'content': content,
        'imageUrl': imageUrl,
        'voiceUrl': voiceUrl,
        'transcription': transcription,
        'voiceDurationSeconds': voiceDuration?.inSeconds,
        'detectedLanguage': detectedLanguage,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'isHelpful': false,
        'helpfulCount': 0,
        'isAcceptedAnswer': false,
        'parentCommentId': parentCommentId,
      };

      // Add comment
      final docRef =
          await _firestore.collection(forumCommentsCollection).add(commentData);

      // Update post comment count and last activity
      await _firestore.collection(forumPostsCollection).doc(postId).update({
        'commentCount': FieldValue.increment(1),
        'lastActivity': Timestamp.fromDate(DateTime.now()),
      });

      // Send notification to the original post author
      await _sendForumReplyNotification(postId, userProfile, content);

      return docRef.id;
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get comments for a specific post
  Stream<List<ForumComment>> getCommentsForPost(String postId) {
    try {
      return _firestore
          .collection(forumCommentsCollection)
          .where('postId', isEqualTo: postId)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ForumComment.fromMap(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting comments: $e');
      throw Exception('Failed to get comments: $e');
    }
  }

  // Mark comment as helpful
  Future<void> markCommentAsHelpful(String commentId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user already voted
      final voteDoc = await _firestore
          .collection(forumVotesCollection)
          .doc('${currentUser.uid}_$commentId')
          .get();

      if (voteDoc.exists) {
        return; // User already voted
      }

      // Add vote record
      await _firestore
          .collection(forumVotesCollection)
          .doc('${currentUser.uid}_$commentId')
          .set({
        'userId': currentUser.uid,
        'commentId': commentId,
        'type': 'helpful',
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      // Increment helpful count
      await _firestore
          .collection(forumCommentsCollection)
          .doc(commentId)
          .update({
        'helpfulCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error marking comment as helpful: $e');
      throw Exception('Failed to mark comment as helpful: $e');
    }
  }

  // Mark comment as accepted answer
  Future<void> markCommentAsAcceptedAnswer(
      String commentId, String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is the post author
      final post = await getPostById(postId);
      if (post == null || post.authorId != currentUser.uid) {
        throw Exception('Only post author can mark accepted answers');
      }

      // Remove accepted answer from other comments in this post
      final batch = _firestore.batch();

      final comments = await _firestore
          .collection(forumCommentsCollection)
          .where('postId', isEqualTo: postId)
          .where('isAcceptedAnswer', isEqualTo: true)
          .get();

      for (final doc in comments.docs) {
        batch.update(doc.reference, {'isAcceptedAnswer': false});
      }

      // Mark the new comment as accepted answer
      final commentRef =
          _firestore.collection(forumCommentsCollection).doc(commentId);
      batch.update(commentRef, {'isAcceptedAnswer': true});

      await batch.commit();
    } catch (e) {
      print('Error marking comment as accepted answer: $e');
      throw Exception('Failed to mark comment as accepted answer: $e');
    }
  }

  // Get trending posts (posts with high activity)
  Stream<List<ForumPost>> getTrendingPosts({int limit = 10}) {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      return _firestore
          .collection(forumPostsCollection)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('timestamp', descending: true)
          .orderBy('commentCount', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ForumPost.fromMap(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting trending posts: $e');
      throw Exception('Failed to get trending posts: $e');
    }
  }

  // Get posts by specific user
  Stream<List<ForumPost>> getPostsByUser(String userId) {
    try {
      return _firestore
          .collection(forumPostsCollection)
          .where('authorId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ForumPost.fromMap(doc.data(), doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error getting user posts: $e');
      throw Exception('Failed to get user posts: $e');
    }
  }

  // Delete a forum post (only by author or admin)
  Future<void> deletePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get the post to check ownership
      final post = await getPostById(postId);
      if (post == null) {
        throw Exception('Post not found');
      }

      if (post.authorId != currentUser.uid) {
        throw Exception('Only post author can delete posts');
      }

      // Delete all comments for this post
      final comments = await _firestore
          .collection(forumCommentsCollection)
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();

      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }

      // Delete the post
      batch.delete(_firestore.collection(forumPostsCollection).doc(postId));

      await batch.commit();
    } catch (e) {
      print('Error deleting post: $e');
      throw Exception('Failed to delete post: $e');
    }
  }

  // Delete a comment (only by author)
  Future<void> deleteComment(String commentId, String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get the comment to check ownership
      final commentDoc = await _firestore
          .collection(forumCommentsCollection)
          .doc(commentId)
          .get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final comment = ForumComment.fromMap(
        commentDoc.data() as Map<String, dynamic>,
        commentDoc.id,
      );

      if (comment.authorId != currentUser.uid) {
        throw Exception('Only comment author can delete comments');
      }

      // Delete the comment
      await _firestore
          .collection(forumCommentsCollection)
          .doc(commentId)
          .delete();

      // Update post comment count
      await _firestore.collection(forumPostsCollection).doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      print('Error deleting comment: $e');
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Private helper methods for file uploads
  Future<String> _uploadForumImage(File imageFile, String userId) async {
    try {
      final extension = imageFile.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'forum_image_${userId}_$timestamp.$extension';

      final ref =
          FirebaseStorage.instance.ref().child('forum_images').child(fileName);

      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload forum image: $e');
    }
  }

  Future<String> _uploadForumVoice(File voiceFile, String userId) async {
    try {
      final extension = voiceFile.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'forum_voice_${userId}_$timestamp.$extension';

      final ref =
          FirebaseStorage.instance.ref().child('forum_voices').child(fileName);

      final uploadTask = await ref.putFile(voiceFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload forum voice: $e');
    }
  }

  /// Send notification to original post author when someone replies
  Future<void> _sendForumReplyNotification(String postId,
      Map<String, dynamic> replierProfile, String replyContent) async {
    try {
      // Get the original post to find the author
      final postDoc =
          await _firestore.collection(forumPostsCollection).doc(postId).get();
      if (!postDoc.exists) {
        print('Post not found for forum reply notification');
        return;
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      final originalAuthorId = postData['authorId'];
      final postTitle = postData['title'] ?? 'Forum Post';

      if (originalAuthorId == null ||
          originalAuthorId == FirebaseAuth.instance.currentUser?.uid) {
        // Don't send notification if replying to own post
        return;
      }

      final replierName = replierProfile['fullName'] ??
          replierProfile['displayName'] ??
          replierProfile['name'] ??
          'A seller';

      // Send notification using the standardized service
      await NotificationService.sendForumNotification(
        userId: originalAuthorId,
        type: NotificationType.forumReply,
        postTitle: postTitle,
        replierName: replierName,
        replyContent: replyContent,
        targetRole: UserRole.seller,
        priority: NotificationPriority.low,
        additionalData: {
          'postId': postId,
          'replierId': FirebaseAuth.instance.currentUser?.uid,
        },
      );

      print('Forum reply notification sent to: $originalAuthorId');
    } catch (e) {
      print('Error sending forum reply notification: $e');
      // Don't throw error - notification failure shouldn't prevent reply creation
    }
  }
}
