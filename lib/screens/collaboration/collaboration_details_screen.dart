import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/collab_service.dart';
import '../../models/collab_model.dart';
import 'collaboration_application_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_project_screen.dart';
import 'project_management.dart';

class CollaborationDetailsScreen extends StatefulWidget {
  final CollaborationRequest collaboration;

  const CollaborationDetailsScreen({
    Key? key,
    required this.collaboration,
  }) : super(key: key);

  @override
  State<CollaborationDetailsScreen> createState() =>
      _CollaborationDetailsScreenState();
}

class _CollaborationDetailsScreenState extends State<CollaborationDetailsScreen>
    with TickerProviderStateMixin {
  final CollaborationService _collaborationService = CollaborationService();
  late TabController _tabController;
  bool _isLoading = false;

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
    return StreamBuilder<CollaborationRequest?>(
      stream: _getCollaborationStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: craftBeige,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(craftGold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading project details...',
                    style: GoogleFonts.inter(color: craftBrown),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: craftBeige,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading project',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: craftDarkBrown,
                    ),
                  ),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final collaboration = snapshot.data ?? widget.collaboration;
        return _buildMainContent(collaboration);
      },
    );
  }

  // Add stream to get real-time collaboration updates
  Stream<CollaborationRequest?> _getCollaborationStream() {
    return FirebaseFirestore.instance
        .collection('collaboration_projects') // Changed from collaboration_requests
        .doc(widget.collaboration.id)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return CollaborationRequest.fromMap({
          ...doc.data()!,
          'id': doc.id,
        });
      }
      return null;
    });
  }

  Widget _buildMainContent(CollaborationRequest collaboration) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLeader = currentUser?.uid == collaboration.leadArtisanId;
    final isParticipant = collaboration.collaboratorIds.contains(currentUser?.uid);
    final canApply = currentUser != null &&
        !isLeader &&
        !isParticipant &&
        collaboration.status == 'open';

    return Scaffold(
      backgroundColor: craftBeige,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: craftBrown,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [craftBrown, craftDarkBrown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: Text(
                'Craft Project',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
            ),
            actions: [
              // Add Edit Button for project leaders
              if (isLeader)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  onPressed: () => _navigateToEditScreen(collaboration),
                  tooltip: 'Edit Project',
                ),
              if (isLeader)
                PopupMenuButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(Icons.update, size: 18, color: craftBrown),
                          const SizedBox(width: 8),
                          Text(
                            'Update Status',
                            style: GoogleFonts.inter(color: craftDarkBrown),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'status') {
                      _showStatusUpdateDialog(collaboration);
                    }
                  },
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: craftGold,
              unselectedLabelColor: Colors.white70,
              indicatorColor: craftGold,
              labelStyle:
                  GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Roles'),
                Tab(text: 'Applications'),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(collaboration, isLeader, isParticipant),
                _buildRolesTab(collaboration, canApply),
                _buildApplicationsTab(collaboration, isLeader),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(CollaborationRequest collaboration, bool isLeader, bool isParticipant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, craftBeige.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: craftBrown.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: craftLightBrown.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        collaboration.title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: craftDarkBrown,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  collaboration.description,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: craftBrown.withOpacity(0.9),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                if (isLeader)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          craftGold.withOpacity(0.2),
                          craftGold.withOpacity(0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: craftGold.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 20, color: craftGold),
                        const SizedBox(width: 8),
                        Text(
                          'Master Artisan & Project Leader',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: craftDarkBrown,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  )
                else if (isParticipant)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          craftBrown.withOpacity(0.2),
                          craftBrown.withOpacity(0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: craftBrown.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.handyman, size: 18, color: craftBrown),
                        const SizedBox(width: 8),
                        Text(
                          'Craft Team Member',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: craftBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Project Metrics Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildCraftMetricCard(
                'Total Budget',
                '₹${collaboration.totalBudget.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
                const Color(0xFF228B22),
              ),
              _buildCraftMetricCard(
                'Team Size',
                '${collaboration.collaboratorIds.length + 1} Artisans',
                Icons.groups,
                craftBrown,
              ),
              _buildCraftMetricCard(
                'Craft Roles',
                '${collaboration.requiredRoles.length} Specialties',
                Icons.handyman,
                const Color(0xFF8B008B),
              ),
              _buildCraftMetricCard(
                'Deadline',
                _formatDeadline(collaboration.deadline),
                Icons.schedule,
                const Color(0xFFFF6347),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Project Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: craftBrown.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: craftLightBrown.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: craftGold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(Icons.info_rounded, color: craftBrown, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Craft Project Details',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: craftDarkBrown,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Category', collaboration.category),
                _buildDetailRow('Created', _formatDate(collaboration.createdAt)),
                _buildDetailRow('Last Updated', _formatDate(collaboration.updatedAt)),
                if (collaboration.additionalNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Additional Notes:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: craftBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: craftBeige.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: craftLightBrown.withOpacity(0.3)),
                    ),
                    child: Text(
                      collaboration.additionalNotes,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: craftBrown,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesTab(CollaborationRequest collaboration, bool canApply) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: collaboration.requiredRoles.length,
      itemBuilder: (context, index) {
        final role = collaboration.requiredRoles[index];
        return _buildCraftRoleCard(role, collaboration, canApply);
      },
    );
  }

  Widget _buildApplicationsTab(CollaborationRequest collaboration, bool isLeader) {
    if (!isLeader) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: craftGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: craftGold.withOpacity(0.3), width: 2),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: craftBrown,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Master Artisan Access Only',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: craftDarkBrown,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Only the project leader can view and manage collaboration applications',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: craftBrown.withOpacity(0.8),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<CollaborationApplication>>(
      stream: _collaborationService.getCollaborationApplications(collaboration.id),
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
                  'Loading applications...',
                  style: GoogleFonts.inter(color: craftBrown),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading applications: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          );
        }

        final applications = snapshot.data ?? [];

        if (applications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: craftBeige.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: craftLightBrown.withOpacity(0.5), width: 2),
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: craftBrown,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Applications Yet',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: craftDarkBrown,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Applications from fellow artisans will appear here once they show interest in joining your craft project',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: craftBrown.withOpacity(0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            return _buildCraftApplicationCard(applications[index]);
          },
        );
      },
    );
  }

  Widget _buildCraftRoleCard(CollaborationRole role, CollaborationRequest collaboration, bool canApply) {
    final isFilled = role.status == 'filled';
    final isOpen = role.status == 'open';
    final assignedCount = role.assignedArtisanIds.length;
    final maxCount = role.maxArtisans;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            isFilled
                ? const Color(0xFF228B22).withOpacity(0.05)
                : isOpen
                    ? craftGold.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFilled
              ? const Color(0xFF228B22).withOpacity(0.3)
              : isOpen
                  ? craftGold.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: craftBrown.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: craftGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.handyman, color: craftBrown, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: craftDarkBrown,
                  ),
                ),
              ),
              _buildRoleStatusBadge(role.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            role.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: craftBrown.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
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
                  child: _buildRoleMetric(
                      'Budget', '₹${role.allocatedBudget.toStringAsFixed(0)}'),
                ),
                Container(
                    height: 30,
                    width: 1,
                    color: craftLightBrown.withOpacity(0.5)),
                Expanded(
                  child: _buildRoleMetric('Artisans', '$assignedCount/$maxCount'),
                ),
                Container(
                    height: 30,
                    width: 1,
                    color: craftLightBrown.withOpacity(0.5)),
                Expanded(
                  child: _buildRoleMetric('Domain', role.domain),
                ),
              ],
            ),
          ),
          
          // Show assigned members if any
          if (assignedCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, 
                           color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned Members ($assignedCount)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...role.assignedArtisanIds.take(3).map((memberId) => 
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getMemberInfo(memberId),
                      builder: (context, snapshot) {
                        final memberInfo = snapshot.data;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.green.shade600,
                                child: Text(
                                  (memberInfo?['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  memberInfo?['name'] ?? 'Loading...',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                              Icon(Icons.check_circle, 
                                   color: Colors.green.shade600, size: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (assignedCount > 3) 
                    Text(
                      '+ ${assignedCount - 3} more members',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.green.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (role.requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: role.requiredSkills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: craftLightBrown.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: craftLightBrown),
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: craftBrown,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          
          // Check if user can apply for this role
          StreamBuilder<List<CollaborationApplication>>(
            stream: _collaborationService
                .getCollaborationApplications(collaboration.id),
            builder: (context, snapshot) {
              final applications = snapshot.data ?? [];
              final currentUser = FirebaseAuth.instance.currentUser;
              
              // Check if current user has already applied for this specific role
              final hasAppliedForThisRole = applications.any((app) =>
                  app.artisanId == currentUser?.uid && app.roleId == role.id);
              
              // Check if user's application is pending for this role
              final pendingApplication = applications.firstWhere(
                (app) => app.artisanId == currentUser?.uid && 
                         app.roleId == role.id && 
                         app.status == 'pending',
                orElse: () => CollaborationApplication(
                  id: '',
                  collaborationRequestId: '',
                  roleId: '',
                  artisanId: '',
                  artisanName: '',
                  artisanEmail: '',
                  proposal: '',
                  proposedRate: 0,
                  estimatedDays: 0,
                  status: '',
                  appliedAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              
              final hasPendingApplication = pendingApplication.id.isNotEmpty;
              
              // Check if user's application was accepted for this role
              final acceptedApplication = applications.firstWhere(
                (app) => app.artisanId == currentUser?.uid && 
                         app.roleId == role.id && 
                         app.status == 'accepted',
                orElse: () => CollaborationApplication(
                  id: '',
                  collaborationRequestId: '',
                  roleId: '',
                  artisanId: '',
                  artisanName: '',
                  artisanEmail: '',
                  proposal: '',
                  proposedRate: 0,
                  estimatedDays: 0,
                  status: '',
                  appliedAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
              
              final hasAcceptedApplication = acceptedApplication.id.isNotEmpty;
              
              // Check if role is actually full (using real-time data)
              final isRoleFull = assignedCount >= maxCount;
              
              if (canApply && !isRoleFull && !hasAppliedForThisRole) {
                // Show apply button if user can apply and hasn't applied yet
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _applyForRole(role, collaboration),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: craftGold,
                          foregroundColor: craftDarkBrown,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.handyman, size: 18),
                        label: Text(
                          'Apply for this Craft Role',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                );
              } else if (hasPendingApplication) {
                // Show pending status if application is under review
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_empty, 
                               color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Application Under Review',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                Text(
                                  'Your application is being reviewed by the project leader',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (hasAcceptedApplication) {
                // Show accepted status if application was approved
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, 
                               color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Application Accepted! 🎉',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                Text(
                                  'Congratulations! You are now part of this craft project',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (isRoleFull) {
                // Show role filled status
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, 
                               color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Role Filled',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  'This role has reached its maximum capacity',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (hasAppliedForThisRole) {
                // Show generic message if application exists but status is neither pending nor accepted
                final myApplication = applications.firstWhere(
                  (app) => app.artisanId == currentUser?.uid && app.roleId == role.id,
                );
                
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.assignment_turned_in, 
                               color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Already Applied',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  'You have already submitted an application for this role',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              
              // If role is not open or user can't apply, don't show anything
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // Helper methods
  Widget _buildRoleStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'filled':
        color = Colors.green;
        label = 'Filled';
        icon = Icons.check_circle;
        break;
      case 'open':
        color = craftGold;
        label = 'Open';
        icon = Icons.radio_button_unchecked;
        break;
      case 'closed':
        color = Colors.grey;
        label = 'Closed';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: craftDarkBrown,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: craftBrown.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCraftMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: craftDarkBrown,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: craftBrown.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: craftBrown.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: craftDarkBrown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCraftApplicationCard(CollaborationApplication application) {
    // Implementation for application card
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: craftBrown.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            application.artisanName,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: craftDarkBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            application.proposal,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: craftBrown.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Rate: ₹${application.proposedRate.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF228B22),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Timeline: ${application.estimatedDays} days',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: craftBrown,
                ),
              ),
            ],
          ),
          if (application.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateApplicationStatus(application.id, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateApplicationStatus(application.id, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Add helper methods
  Future<Map<String, dynamic>?> _getMemberInfo(String memberId) async {
    try {
      // Try retailers collection first
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

      // Try users collection
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? data['displayName'] ?? 'Unknown Member',
          'email': data['email'] ?? '',
        };
      }

      return {'name': 'Unknown Member', 'email': ''};
    } catch (e) {
      print('Error getting member info: $e');
      return {'name': 'Unknown Member', 'email': ''};
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatDeadline(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Due Today';
    } else if (difference == 1) {
      return 'Due Tomorrow';
    } else if (difference <= 7) {
      return 'Due in $difference days';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  void _applyForRole(CollaborationRole role, CollaborationRequest collaboration) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollaborationApplicationScreen(
          collaboration: collaboration,
          role: role,
        ),
      ),
    );
  }

  Future<void> _updateApplicationStatus(String applicationId, String status) async {
    try {
      setState(() => _isLoading = true);
      
      await _collaborationService.updateApplicationStatus(
        widget.collaboration.id,
        applicationId,
        status,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application $status successfully'),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating application: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEditScreen(CollaborationRequest collaboration) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProjectScreen(collaboration: collaboration),
      ),
    );

    if (result == true) {
      // Refresh handled by StreamBuilder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showStatusUpdateDialog(CollaborationRequest collaboration) {
    // Implementation for status update dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Project Status'),
        content: const Text('Status update functionality coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}