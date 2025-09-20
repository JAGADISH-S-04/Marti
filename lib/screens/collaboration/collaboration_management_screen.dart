import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/collab_service.dart';
import '../../models/collab_model.dart';
import 'collaboration_details_screen.dart';
import 'create_collaboration_screen.dart';
import 'collaboration_chat_screen.dart';

class CollaborationManagementScreen extends StatefulWidget {
  const CollaborationManagementScreen({Key? key}) : super(key: key);

  @override
  State<CollaborationManagementScreen> createState() =>
      _CollaborationManagementScreenState();
}

class _CollaborationManagementScreenState
    extends State<CollaborationManagementScreen> with TickerProviderStateMixin {
  final CollaborationService _collaborationService = CollaborationService();
  late TabController _tabController;

  // Craftwork-themed colors
  final Color craftBrown = const Color(0xFF8B4513);
  final Color craftGold = const Color(0xFFD4AF37);
  final Color craftBeige = const Color(0xFFF5F5DC);
  final Color craftDarkBrown = const Color(0xFF5D2E0A);
  final Color craftLightBrown = const Color(0xFFDEB887);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: craftBeige,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [craftBrown, craftDarkBrown],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Collaboration Hub',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: craftGold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: craftGold,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
          tabs: const [
            Tab(text: 'My Projects'),
            Tab(text: 'Available'),
            Tab(text: 'Joined'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyProjectsTab(),
          _buildAvailableProjectsTab(),
          _buildParticipatingTab(),
        ],
      ),
      
    );
  }

  // Add this method to show recent chats for each project card
Widget _buildRecentChatsButton(CollaborationRequest project) {
  return PopupMenuButton<String>(
    icon: Icon(Icons.chat_bubble_outline, color: craftBrown, size: 16),
    tooltip: 'Recent Chats',
    onSelected: (value) {
      if (value == 'team') {
        _openTeamChat(project);
      } else if (value.startsWith('direct_')) {
        final memberId = value.substring(7); // Remove 'direct_' prefix
        _openDirectChatFromList(project, memberId);
      }
    },
    itemBuilder: (context) {
      final currentUser = FirebaseAuth.instance.currentUser;
      final isLeader = currentUser?.uid == project.leadArtisanId;
      
      List<PopupMenuEntry<String>> items = [
        PopupMenuItem<String>(
          value: 'team',
          child: Row(
            children: [
              Icon(Icons.group, size: 16, color: craftBrown),
              const SizedBox(width: 8),
              const Text('Team Chat'),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ];
      
      // Add chat with leader option (if not leader)
      if (!isLeader) {
        items.add(
          PopupMenuItem<String>(
            value: 'direct_${project.leadArtisanId}',
            child: Row(
              children: [
                Icon(Icons.star, size: 16, color: craftGold),
                const SizedBox(width: 8),
                const Text('Project Leader'),
              ],
            ),
          ),
        );
      }
      
      // Add other team members
      for (final memberId in project.collaboratorIds) {
        if (memberId != currentUser?.uid) {
          items.add(
            PopupMenuItem<String>(
              value: 'direct_$memberId',
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: craftBrown,
                    child: Text(
                      'M',
                      style: TextStyle(color: Colors.white, fontSize: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Team Member'),
                ],
              ),
            ),
          );
        }
      }
      
      return items;
    },
  );
}

void _openTeamChat(CollaborationRequest project) {
  final teamChatRoomId = 'team_${project.id}';
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CollaborationChatScreen(
        collaborationId: project.id,
        chatRoomId: teamChatRoomId,
        chatType: 'team',
        collaboration: project,
        currentUserName: 'Current User', // You'll need to get this dynamically
      ),
    ),
  );
}

void _openDirectChatFromList(CollaborationRequest project, String memberId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  // Get member info
  final memberInfo = await _getMemberInfo(memberId);
  final memberName = memberInfo?['name'] ?? 'Team Member';

  // Create consistent chat room ID
  final List<String> userIds = [currentUser.uid, memberId];
  userIds.sort();
  final directChatRoomId = 'direct_${project.id}_${userIds[0]}_${userIds[1]}';
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CollaborationChatScreen(
        collaborationId: project.id,
        chatRoomId: directChatRoomId,
        chatType: 'direct',
        collaboration: project,
        currentUserName: 'Current User',
        otherUserName: memberName,
        otherUserId: memberId,
      ),
    ),
  );
}

Future<Map<String, dynamic>?> _getMemberInfo(String memberId) async {
  try {
    var doc = await FirebaseFirestore.instance
        .collection('retailers')
        .doc(memberId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      return {
        'name': data['fullName'] ?? data['name'] ?? 'Unknown Member',
        'email': data['email'] ?? '',
      };
    }
    return {'name': 'Unknown Member', 'email': ''};
  } catch (e) {
    return {'name': 'Unknown Member', 'email': ''};
  }
}

  Widget _buildMyProjectsTab() {
    return StreamBuilder<List<CollaborationRequest>>(
      stream: _collaborationService.getMyLeadCollaborations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(craftGold),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading your projects...',
                  style: GoogleFonts.inter(
                    color: craftBrown,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
              'Error loading projects', () => setState(() {}));
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return _buildEmptyState(
            Icons.work_outline,
            'No Projects Yet',
            'Create your first collaboration project to work with other artisans and bring beautiful crafts to life',
            'Create Project',
            () => _showCreateCollaborationDialog(),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            return _buildCraftProjectCard(projects[index], isLeader: true);
          },
        );
      },
    );
  }

  Widget _buildAvailableProjectsTab() {
    return StreamBuilder<List<CollaborationRequest>>(
      stream: _collaborationService.getOpenCollaborationRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(craftGold),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding opportunities...',
                  style: GoogleFonts.inter(
                    color: craftBrown,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
              'Error loading projects', () => setState(() {}));
        }

        final projects = snapshot.data ?? [];
        final currentUser = FirebaseAuth.instance.currentUser;

        final availableProjects = projects.where((project) {
          final isNotLeader = project.leadArtisanId != currentUser?.uid;
          final isNotCollaborator =
              !project.collaboratorIds.contains(currentUser?.uid);
          final isOpen = project.status == 'open';
          final hasOpenRoles =
              project.requiredRoles.any((role) => role.status == 'open');

          return isNotLeader && isNotCollaborator && isOpen && hasOpenRoles;
        }).toList();

        if (availableProjects.isEmpty) {
          return _buildEmptyState(
            Icons.search_off,
            'No Opportunities Available',
            'New collaboration projects from fellow artisans will appear here. Check back soon for exciting craft projects!',
            null,
            null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableProjects.length,
          itemBuilder: (context, index) {
            return _buildCraftProjectCard(availableProjects[index],
                isLeader: false);
          },
        );
      },
    );
  }

  Widget _buildParticipatingTab() {
    return StreamBuilder<List<CollaborationRequest>>(
      stream: _collaborationService.getMyCollaborations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(craftGold),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading collaborations...',
                  style: GoogleFonts.inter(
                    color: craftBrown,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
              'Error loading collaborations', () => setState(() {}));
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return _buildEmptyState(
            Icons.group_outlined,
            'No Collaborations Yet',
            'Join collaboration projects to work alongside talented artisans and learn new craft techniques',
            null,
            null,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            return _buildCraftProjectCard(projects[index], isLeader: false);
          },
        );
      },
    );
  }

  Widget _buildCraftProjectCard(CollaborationRequest project,
      {required bool isLeader}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, craftBeige.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: craftBrown.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isLeader
              ? craftGold.withOpacity(0.5)
              : craftLightBrown.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProjectDetails(project),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with role indicator
                Row(
                  children: [
                    if (isLeader)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [craftGold, craftGold.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: craftGold.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: craftDarkBrown,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MASTER ARTISAN',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: craftDarkBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isLeader) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        project.title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: craftDarkBrown,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildCraftStatusBadge(project.status),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  project.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: craftBrown.withOpacity(0.8),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Project metrics in a grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: craftBeige.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: craftLightBrown.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCraftMetric(
                          Icons.currency_rupee,
                          'Budget',
                          '₹${_formatCurrency(project.totalBudget)}',
                          const Color(0xFF228B22),
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: craftLightBrown.withOpacity(0.5),
                      ),
                      Expanded(
                        child: _buildCraftMetric(
                          Icons.groups,
                          'Artisans',
                          '${project.collaboratorIds.length + 1}',
                          craftBrown,
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: craftLightBrown.withOpacity(0.5),
                      ),
                      Expanded(
                        child: _buildCraftMetric(
                          Icons.handyman,
                          'Roles',
                          '${project.requiredRoles.length}',
                          const Color(0xFF8B008B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Category and action button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: craftLightBrown.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: craftLightBrown),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category,
                            size: 14,
                            color: craftBrown,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            project.category,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: craftBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCraftStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'open':
        color = const Color(0xFF228B22);
        text = 'Open';
        icon = Icons.lock_open;
        break;
      case 'in_progress':
        color = const Color(0xFF4169E1);
        text = 'Crafting';
        icon = Icons.build;
        break;
      case 'completed':
        color = const Color(0xFF8B008B);
        text = 'Crafted';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = const Color(0xFFDC143C);
        text = 'Paused';
        icon = Icons.pause_circle;
        break;
      default:
        color = craftBrown;
        text = status;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCraftMetric(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: craftDarkBrown,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: craftBrown.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    IconData icon,
    String title,
    String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    craftGold.withOpacity(0.1),
                    craftBeige.withOpacity(0.3),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: craftGold.withOpacity(0.3), width: 2),
              ),
              child: Icon(
                icon,
                size: 64,
                color: craftBrown,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: craftDarkBrown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: craftBrown.withOpacity(0.8),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: craftGold,
                  foregroundColor: craftDarkBrown,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 8,
                ),
                icon: const Icon(Icons.add_circle),
                label: Text(
                  buttonText,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.red.withOpacity(0.3), width: 2),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: craftDarkBrown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: craftBrown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: craftBrown,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  void _navigateToProjectDetails(CollaborationRequest project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollaborationDetailsScreen(
          collaboration: project,
        ),
      ),
    );
  }

  void _showCreateCollaborationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: craftGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.info_outline, color: craftBrown),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create Collaboration',
                style: GoogleFonts.playfairDisplay(
                  color: craftDarkBrown,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'To create a collaboration project, you need an accepted craft request. Please go to your requests and open one for collaboration.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: craftBrown,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: craftBrown,
            ),
            child: Text(
              'Got it',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
