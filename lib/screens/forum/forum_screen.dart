import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_post_detail_screen.dart';
import 'create_forum_post_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({Key? key}) : super(key: key);

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen>
    with TickerProviderStateMixin {
  final ForumService _forumService = ForumService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  PostCategory? _selectedCategory;
  String _searchQuery = '';
  bool _showOnlyUnresolved = false;

  // Seller theme colors
  final Color backgroundColor = const Color(0xFFF9F9F7);
  final Color primaryTextColor = const Color(0xFF2C1810);
  final Color cardColor = Colors.white;
  final Color accentColor = const Color(0xFF8B4513);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkUserAccess();
  }

  Future<void> _checkUserAccess() async {
    try {
      final userProfile = await _forumService.debugUserProfile();
      if (userProfile == null || userProfile['isRetailer'] != true) {
        // User is not a seller, redirect them
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.forumAccessRestricted),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking user access: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
        title: Text(
          AppLocalizations.of(context)!.artisanForum,
          style: GoogleFonts.inter(
            color: primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: primaryTextColor,
          unselectedLabelColor: primaryTextColor.withOpacity(0.6),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: AppLocalizations.of(context)!.allPosts, icon: const Icon(Icons.forum, size: 20)),
            Tab(text: AppLocalizations.of(context)!.trending, icon: const Icon(Icons.trending_up, size: 20)),
            Tab(text: AppLocalizations.of(context)!.myPosts, icon: const Icon(Icons.person, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllPostsTab(),
                _buildTrendingPostsTab(),
                _buildMyPostsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.width > 600 ? 16 : 8,
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateForumPostScreen(),
              ),
            );
          },
          backgroundColor: accentColor,
          foregroundColor: cardColor,
          icon: const Icon(Icons.add),
          label: Text(
            AppLocalizations.of(context)!.askQuestion,
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
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
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchPostsHint,
              prefixIcon: Icon(Icons.search, color: primaryTextColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide:
                    BorderSide(color: primaryTextColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          const SizedBox(height: 12),

          // Filters
          Row(
            children: [
              // Category filter
              Expanded(
                child: DropdownButtonFormField<PostCategory>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.category,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem<PostCategory>(
                      value: null,
                      child: Text(AppLocalizations.of(context)!.allCategories),
                    ),
                    ...PostCategory.values.map((category) {
                      return DropdownMenuItem<PostCategory>(
                        value: category,
                        child: Row(
                          children: [
                            Text(category.icon),
                            const SizedBox(width: 8),
                            Text(category.displayName),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Resolved filter
              FilterChip(
                label: Text(AppLocalizations.of(context)!.unresolvedOnly),
                selected: _showOnlyUnresolved,
                onSelected: (selected) {
                  setState(() {
                    _showOnlyUnresolved = selected;
                  });
                },
                selectedColor: accentColor.withOpacity(0.2),
                checkmarkColor: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllPostsTab() {
    return StreamBuilder<List<ForumPost>>(
      stream: _forumService.getForumPosts(
        category: _selectedCategory,
        isResolved: _showOnlyUnresolved ? false : null,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.errorLoadingPosts(snapshot.error.toString())),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text(AppLocalizations.of(context)!.retry),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No posts found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to ask a question!',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index]);
          },
        );
      },
    );
  }

  Widget _buildTrendingPostsTab() {
    return StreamBuilder<List<ForumPost>>(
      stream: _forumService.getTrendingPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading trending posts: ${snapshot.error}'),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('No trending posts this week'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index], showTrendingBadge: true);
          },
        );
      },
    );
  }

  Widget _buildMyPostsTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('Please log in to view your posts'),
      );
    }

    return StreamBuilder<List<ForumPost>>(
      stream: _forumService.getPostsByUser(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading your posts: ${snapshot.error}'),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Text('You haven\'t posted any questions yet'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index], showAuthorActions: true);
          },
        );
      },
    );
  }

  Widget _buildPostCard(ForumPost post,
      {bool showTrendingBadge = false, bool showAuthorActions = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ForumPostDetailScreen(postId: post.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category, priority, and status
              Row(
                children: [
                  // Category
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryTextColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(post.category.icon,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          post.category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Priority indicator
                  if (post.priority != PostPriority.normal)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            _getPriorityColor(post.priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getPriorityColor(post.priority)
                                .withOpacity(0.3)),
                      ),
                      child: Text(
                        post.priority.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getPriorityColor(post.priority),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Status badges
                  if (showTrendingBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up,
                              size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 2),
                          Text(
                            AppLocalizations.of(context)!.trendingBadge,
                            style: TextStyle(
                                fontSize: 10, color: Colors.orange[700]),
                          ),
                        ],
                      ),
                    ),

                  if (post.isResolved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: Colors.green[700]),
                          const SizedBox(width: 2),
                          Text(
                            AppLocalizations.of(context)!.resolvedBadge,
                            style: TextStyle(
                                fontSize: 10, color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Content preview
              Text(
                post.content,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Voice message indicator
              if (post.voiceUrl != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.mic, size: 16, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.voiceMessageIncluded,
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Footer with author, stats, and time
              Row(
                children: [
                  // Author info
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: accentColor,
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(post.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats
                  _buildStatChip(Icons.visibility, post.viewCount.toString()),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.comment, post.commentCount.toString()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
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
}
