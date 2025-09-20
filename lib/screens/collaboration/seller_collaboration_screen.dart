import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/collab_service.dart';
import '../../models/collab_model.dart';
import '../craft_it/seller_view.dart';
import 'collaboration_management_screen.dart';
import 'collaboration_details_screen.dart';
import '../../navigation/Sellerside_navbar.dart';

class SellerCollaborationScreen extends StatefulWidget {
  const SellerCollaborationScreen({Key? key}) : super(key: key);

  @override
  State<SellerCollaborationScreen> createState() =>
      _SellerCollaborationScreenState();
}

class _SellerCollaborationScreenState extends State<SellerCollaborationScreen>
    with SingleTickerProviderStateMixin {
  final CollaborationService _collaborationService = CollaborationService();
  late TabController _tabController;

  // Black color scheme
  final Color primaryColor = Colors.black;
  final Color accentColor = const Color.fromARGB(255, 51, 51, 51); // Dark gray
  final Color secondaryColor = const Color.fromARGB(255, 130, 200, 116); // Medium gray
  final Color backgroundColor = const Color(0xFFF8F8F8); // Light gray background
  final Color cardColor = Colors.white;
  final Color successColor = const Color(0xFF10B981);
  final Color warningColor = const Color.fromARGB(255, 177, 139, 83);
  final Color inProgressColor = const Color.fromARGB(255, 61, 97, 167); // Gray for in-progress
  final Color completedColor = const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainSellerScaffold(
      currentIndex: null, // Don't highlight any bottom nav item
      body: Column(
        children: [
          // Header Section - Clean white container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Collaborations',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect, create, and collaborate with fellow artisans',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: primaryColor.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: primaryColor,
              unselectedLabelColor: primaryColor.withOpacity(0.6),
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              tabs: const [
                Tab(text: 'My Projects'),
                Tab(text: 'Discover'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: Container(
              color: backgroundColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyActiveCollaborations(),
                  _buildAvailableOpportunities(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to determine project status
  String _getProjectStatus(CollaborationRequest project) {
    if (project.status == 'completed') {
      return 'completed';
    }
    
    int totalRoles = project.requiredRoles.length;
    int filledRoles = project.requiredRoles.where((role) => role.status == 'filled').length;
    
    if (filledRoles == totalRoles) {
      return 'in_progress';
    } else {
      return 'open';
    }
  }

  // Helper method to get status color and text
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'open':
        return {
          'text': 'OPEN ROLES',
          'color': successColor,
          'icon': Icons.door_front_door_outlined,
        };
      case 'in_progress':
        return {
          'text': 'IN PROGRESS',
          'color': inProgressColor, // Now using gray
          'icon': Icons.work_outline,
        };
      case 'completed':
        return {
          'text': 'COMPLETED',
          'color': completedColor,
          'icon': Icons.check_circle_outline,
        };
      default:
        return {
          'text': 'UNKNOWN',
          'color': primaryColor,
          'icon': Icons.help_outline,
        };
    }
  }

  Widget _buildMyActiveCollaborations() {
    return StreamBuilder<List<CollaborationRequest>>(
      stream: _collaborationService.getMyLeadCollaborations(),
      builder: (context, leadSnapshot) {
        if (leadSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final leadProjects = leadSnapshot.data ?? [];
        return StreamBuilder<List<CollaborationRequest>>(
          stream: _collaborationService.getMyCollaborations(),
          builder: (context, memberSnapshot) {
            if (memberSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            final memberProjects = memberSnapshot.data ?? [];
            final allActiveProjects = [...leadProjects, ...memberProjects]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (allActiveProjects.isEmpty) {
              return _buildEmptyStateCard(
                icon: Icons.groups_outlined,
                title: 'No Active Projects',
                message: 'Start collaborating by creating or joining projects',
                actionText: 'Browse Projects',
                onAction: () => _tabController.animateTo(1),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: allActiveProjects.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final project = allActiveProjects[index];
                return _buildCollaborationCard(
                  project,
                  leadProjects.contains(project),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAvailableOpportunities() {
    return StreamBuilder<List<CollaborationRequest>>(
      stream: _collaborationService.getOpenCollaborationRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final allProjects = snapshot.data ?? [];
        final currentUser = FirebaseAuth.instance.currentUser;

        final availableProjects = allProjects.where((project) {
          final isNotLeader = project.leadArtisanId != currentUser?.uid;
          final isNotMember =
              !project.collaboratorIds.contains(currentUser?.uid);
          final isOpen = project.status == 'open';
          final hasOpenRoles =
              project.requiredRoles.any((role) => role.status == 'open');
          return isNotLeader && isNotMember && isOpen && hasOpenRoles;
        }).toList();

        if (availableProjects.isEmpty) {
          return _buildEmptyStateCard(
            icon: Icons.explore_outlined,
            title: 'No Opportunities Found',
            message: 'New collaboration projects will appear here as they become available',
            actionText: 'Refresh',
            onAction: () => setState(() {}),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: availableProjects.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildOpportunityCard(availableProjects[index]);
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(primaryColor),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading collaborations...',
            style: GoogleFonts.inter(
              color: primaryColor.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationCard(CollaborationRequest project, bool isLeader) {
    final projectStatus = _getProjectStatus(project);
    final statusInfo = _getStatusInfo(projectStatus);
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CollaborationDetailsScreen(collaboration: project),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.business_center_outlined,
                        color: cardColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Role status tag (PROJECT LEADER or JOINED)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isLeader 
                                      ? warningColor
                                      : primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isLeader ? 'PROJECT LEADER' : 'JOINED',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: cardColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Project status tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusInfo['color'].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusInfo['color'].withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusInfo['icon'],
                                      size: 10,
                                      color: statusInfo['color'],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusInfo['text'],
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: statusInfo['color'],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildEnhancedInfoChip(
                        '₹${_formatCurrency(project.totalBudget)}',
                        Icons.payments_outlined,
                        successColor,
                      ),
                      const SizedBox(width: 12),
                      _buildEnhancedInfoChip(
                        '${project.collaboratorIds.length + 1} Artisans',
                        Icons.group_outlined,
                        primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpportunityCard(CollaborationRequest project) {
    int openRoles = project.requiredRoles.where((r) => r.status == 'open').length;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CollaborationDetailsScreen(collaboration: project),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, accentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.explore_outlined,
                        color: cardColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        project.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'OPEN',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: successColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.05),
                        accentColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildEnhancedInfoChip(
                        '₹${_formatCurrency(project.totalBudget)}',
                        Icons.payments_outlined,
                        successColor,
                      ),
                      const SizedBox(width: 12),
                      _buildEnhancedInfoChip(
                        '$openRoles Open Roles',
                        Icons.person_add_alt_1_outlined,
                        warningColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    accentColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: primaryColor.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: primaryColor.withOpacity(0.6),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: cardColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionText,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
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

  Widget _buildEnhancedInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return NumberFormat.decimalPattern('en_IN').format(amount);
    }
  }
}