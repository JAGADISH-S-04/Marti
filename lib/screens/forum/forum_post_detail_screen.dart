import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../widgets/CI_chat_voice_recorder.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final String postId;

  const ForumPostDetailScreen({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final ForumService _forumService = ForumService();
  final TextEditingController _commentController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isSubmittingComment = false;
  bool _isPlayingVoice = false;
  String? _currentPlayingVoiceUrl;

  // Seller theme colors
  final Color backgroundColor = const Color(0xFFF9F9F7);
  final Color primaryTextColor = const Color(0xFF2C1810);
  final Color cardColor = Colors.white;
  final Color accentColor = const Color(0xFF8B4513);

  @override
  void initState() {
    super.initState();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _incrementViewCount() async {
    try {
      await _forumService.incrementViewCount(widget.postId);
    } catch (e) {
      // Ignore view count errors
    }
  }

  Future<void> _submitComment({
    File? voiceFile,
    String? transcription,
    Duration? voiceDuration,
  }) async {
    if (_commentController.text.trim().isEmpty && voiceFile == null) {
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      await _forumService.addComment(
        postId: widget.postId,
        content: _commentController.text.trim(),
        voiceFile: voiceFile,
        transcription: transcription,
        voiceDuration: voiceDuration,
      );

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  Future<void> _playVoiceMessage(String voiceUrl) async {
    try {
      if (_isPlayingVoice && _currentPlayingVoiceUrl == voiceUrl) {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingVoice = false;
          _currentPlayingVoiceUrl = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(voiceUrl));
        setState(() {
          _isPlayingVoice = true;
          _currentPlayingVoiceUrl = voiceUrl;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlayingVoice = false;
              _currentPlayingVoiceUrl = null;
            });
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing voice message: $e')),
      );
    }
  }

  Future<void> _markAsResolved() async {
    try {
      await _forumService.markPostAsResolved(widget.postId);
      // No need to refresh - StreamBuilder will automatically update
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post marked as resolved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking as resolved: $e')),
        );
      }
    }
  }

  Future<void> _markCommentAsHelpful(String commentId) async {
    try {
      await _forumService.markCommentAsHelpful(commentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as helpful')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAsAcceptedAnswer(String commentId) async {
    try {
      await _forumService.markCommentAsAcceptedAnswer(commentId, widget.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as accepted answer')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ForumPost?>(
      stream: _forumService.getPostByIdStream(widget.postId),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading...'),
              backgroundColor: primaryTextColor,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!postSnapshot.hasData || postSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Post Not Found'),
              backgroundColor: primaryTextColor,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text('Post not found or has been deleted.'),
            ),
          );
        }

        final post = postSnapshot.data!;

        // Get real-time comment count
        return StreamBuilder<List<ForumComment>>(
          stream: _forumService.getCommentsForPost(widget.postId),
          builder: (context, commentsSnapshot) {
            final realTimeCommentCount = commentsSnapshot.hasData
                ? commentsSnapshot.data!.length
                : post.commentCount;

            return _buildPostDetail(post, realTimeCommentCount);
          },
        );
      },
    );
  }

  Widget _buildPostDetail(ForumPost post, int realTimeCommentCount) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          post.title,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: primaryTextColor,
        foregroundColor: Colors.white,
        actions: [
          // Resolve button for post author
          if (!post.isResolved &&
              post.authorId == FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              onPressed: _markAsResolved,
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Mark as resolved',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostHeader(post, realTimeCommentCount),
                  _buildPostContent(post),
                  _buildCommentsSection(post, realTimeCommentCount),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader(ForumPost post, int realTimeCommentCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category and priority badges
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryTextColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(post.category.icon),
                    const SizedBox(width: 6),
                    Text(
                      post.category.displayName,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (post.priority != PostPriority.normal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(post.priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPriorityColor(post.priority).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    post.priority.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getPriorityColor(post.priority),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (post.isResolved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Author and metadata
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryTextColor,
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Posted ${_formatTimeAgo(post.timestamp)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Stats
              _buildStatChip(Icons.visibility, post.viewCount.toString()),
              const SizedBox(width: 12),
              _buildStatChip(Icons.comment, realTimeCommentCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(ForumPost post) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text content
          Text(
            post.content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),

          // Voice message if present
          if (post.voiceUrl != null) ...[
            const SizedBox(height: 16),
            _buildVoiceMessagePlayer(
              post.voiceUrl!,
              post.transcription,
              post.voiceDuration,
            ),
          ],

          // Image if present
          if (post.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error),
                    ),
                  );
                },
              ),
            ),
          ],

          // Tags if present
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: post.tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: accentColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: primaryTextColor, fontSize: 12),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceMessagePlayer(
      String voiceUrl, String? transcription, Duration? duration) {
    final isPlaying = _isPlayingVoice && _currentPlayingVoiceUrl == voiceUrl;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _playVoiceMessage(voiceUrl),
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: primaryTextColor,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlaying ? 'Playing voice message...' : 'Voice message',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                      ),
                    ),
                    if (duration != null)
                      Text(
                        'Duration: ${_formatDuration(duration)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (transcription != null && transcription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transcription:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transcription,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection(ForumPost post, int realTimeCommentCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Answers ($realTimeCommentCount)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          StreamBuilder<List<ForumComment>>(
            stream: _forumService.getCommentsForPost(widget.postId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading comments: ${snapshot.error}'),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No answers yet. Be the first to help!'),
                );
              }

              // Sort comments - accepted answers first, then by helpful count
              comments.sort((a, b) {
                if (a.isAcceptedAnswer && !b.isAcceptedAnswer) return -1;
                if (!a.isAcceptedAnswer && b.isAcceptedAnswer) return 1;
                return b.helpfulCount.compareTo(a.helpfulCount);
              });

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  return _buildCommentCard(comments[index], post);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(ForumComment comment, ForumPost post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPostAuthor = post.authorId == currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: primaryTextColor,
                child: Text(
                  comment.authorName.isNotEmpty
                      ? comment.authorName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (comment.isAcceptedAnswer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 12, color: Colors.green[700]),
                                const SizedBox(width: 2),
                                Text(
                                  'Accepted Answer',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimeAgo(comment.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Comment content
          Text(
            comment.content,
            style: const TextStyle(fontSize: 14),
          ),

          // Voice message if present
          if (comment.voiceUrl != null) ...[
            const SizedBox(height: 12),
            _buildVoiceMessagePlayer(
              comment.voiceUrl!,
              comment.transcription,
              comment.voiceDuration,
            ),
          ],

          // Image if present
          if (comment.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                comment.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.error)),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Comment actions
          Row(
            children: [
              // Helpful button
              TextButton.icon(
                onPressed: () => _markCommentAsHelpful(comment.id),
                icon: const Icon(Icons.thumb_up, size: 16),
                label: Text('Helpful (${comment.helpfulCount})'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),

              const SizedBox(width: 8),

              // Accept answer button (only for post author)
              if (isPostAuthor && !comment.isAcceptedAnswer && !post.isResolved)
                TextButton.icon(
                  onPressed: () => _markAsAcceptedAnswer(comment.id),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Accept Answer'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green[700],
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Answer',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your knowledge and help others...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Voice recorder
              ChatVoiceRecorder(
                onVoiceRecorded: (audioFile, transcription, duration) {
                  _submitComment(
                    voiceFile: audioFile,
                    transcription: transcription,
                    voiceDuration: duration,
                  );
                },
                primaryColor: primaryTextColor,
                accentColor: accentColor,
              ),

              const SizedBox(width: 8),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmittingComment ? null : () => _submitComment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmittingComment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(PostPriority priority) {
    switch (priority) {
      case PostPriority.low:
        return Colors.blue;
      case PostPriority.normal:
        return Colors.grey;
      case PostPriority.high:
        return Colors.orange;
      case PostPriority.urgent:
        return Colors.red;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
