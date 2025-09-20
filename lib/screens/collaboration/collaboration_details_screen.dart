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
import 'collaboration_chat_screen.dart';
import '../../navigation/Sellerside_navbar.dart';

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

  // Black color scheme to match collaboration screen
  final Color primaryColor = Colors.black;
  final Color accentColor = const Color(0xFF333333);
  final Color secondaryColor = const Color.fromARGB(255, 84, 190, 52);
  final Color backgroundColor = const Color(0xFFF8F8F8);
  final Color cardColor = Colors.white;
  final Color successColor = const Color(0xFF10B981);
  final Color warningColor = const Color(0xFFF59E0B);
  final Color inProgressColor = const Color.fromARGB(255, 81, 101, 140);
  final Color completedColor = const Color(0xFF8B5CF6);

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
          return MainSellerScaffold(
            currentIndex: null,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading project details...',
                    style: GoogleFonts.inter(
                      color: primaryColor.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MainSellerScaffold(
            currentIndex: null,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading project',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
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
        .collection('collaboration_projects')
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
    final isParticipant =
        collaboration.collaboratorIds.contains(currentUser?.uid);
    final canApply = currentUser != null &&
        !isLeader &&
        !isParticipant &&
        collaboration.status == 'open';

    return MainSellerScaffold(
      currentIndex: null,
      body: Column(
        children: [
          // Header Section
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        collaboration.title,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    if (isLeader) ...[
                      Container(
                        child: IconButton(
                          icon: Icon(Icons.edit, color: primaryColor),
                          onPressed: () => _navigateToEditScreen(collaboration),
                          tooltip: 'Edit Project',
                        ),
                      ),
                      const SizedBox(width: 8),
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
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Project Details & Management',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: primaryColor.withOpacity(0.7),
                  ),
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
                Tab(text: 'Overview'),
                Tab(text: 'Roles'),
                Tab(text: 'Applications'),
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
                  _buildOverviewTab(collaboration, isLeader, isParticipant),
                  _buildRolesTab(collaboration, canApply),
                  _buildApplicationsTab(collaboration, isLeader),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
      CollaborationRequest collaboration, bool isLeader, bool isParticipant) {
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
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
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
                        collaboration.title,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                    _buildProjectStatusBadge(collaboration.status),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  collaboration.description,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: primaryColor.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isLeader)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: warningColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 20, color: cardColor),
                            const SizedBox(width: 8),
                            Text(
                              'PROJECT LEADER',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cardColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isParticipant)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.handyman, size: 18, color: cardColor),
                            const SizedBox(width: 8),
                            Text(
                              'JOINED',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cardColor,
                                letterSpacing: 0.5,
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

          const SizedBox(height: 20),

          // Project Status Card (New)
          if (isLeader || isParticipant)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: _getStatusColor(collaboration.status).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Project Status',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      if (isLeader)
                        TextButton.icon(
                          onPressed: () =>
                              _showStatusUpdateDialog(collaboration),
                          icon: Icon(
                            Icons.edit,
                            size: 16,
                            color: _getStatusColor(collaboration.status),
                          ),
                          label: Text(
                            'Change',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _getStatusColor(collaboration.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(collaboration.status)
                          .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(collaboration.status)
                            .withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getStatusIcon(collaboration.status),
                              color: _getStatusColor(collaboration.status),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Status',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: primaryColor.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  _getStatusDisplayText(collaboration.status),
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _getStatusColor(collaboration.status),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(collaboration.status),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                collaboration.status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cardColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getStatusDescription(collaboration.status),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: primaryColor.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last updated: ${_formatDate(collaboration.updatedAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: primaryColor.withOpacity(0.6),
                        ),
                      ),
                    ],
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
              _buildMetricCard(
                'Total Budget',
                '₹${collaboration.totalBudget.toStringAsFixed(0)}',
                Icons.account_balance_wallet,
                successColor,
              ),
              _buildMetricCard(
                'Team Size',
                '${collaboration.collaboratorIds.length + 1} Artisans',
                Icons.groups,
                primaryColor,
              ),
              _buildMetricCard(
                'Roles',
                '${collaboration.requiredRoles.length} Specialties',
                Icons.handyman,
                inProgressColor,
              ),
              _buildMetricCard(
                'Deadline',
                _formatDeadline(collaboration.deadline),
                Icons.schedule,
                warningColor,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Team Communication Section
          if (isLeader || isParticipant)
            _buildTeamCommunicationSection(collaboration),

          const SizedBox(height: 20),

          // Project Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.info_rounded,
                          color: primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Project Details',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Category', collaboration.category),
                _buildDetailRow(
                    'Created', _formatDate(collaboration.createdAt)),
                _buildDetailRow(
                    'Last Updated', _formatDate(collaboration.updatedAt)),
                if (collaboration.additionalNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Additional Notes:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      collaboration.additionalNotes,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: primaryColor.withOpacity(0.8),
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
        return _buildRoleCard(role, collaboration, canApply);
      },
    );
  }

  Widget _buildApplicationsTab(
      CollaborationRequest collaboration, bool isLeader) {
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
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: primaryColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Access Restricted',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Only project leaders can view and manage applications',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: primaryColor.withOpacity(0.7),
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
      stream:
          _collaborationService.getCollaborationApplications(collaboration.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(primaryColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading applications...',
                  style: GoogleFonts.inter(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: 16,
                  ),
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
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: primaryColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Applications Yet',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Applications from artisans will appear here when they apply for roles',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: primaryColor.withOpacity(0.7),
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
            return _buildApplicationCard(applications[index]);
          },
        );
      },
    );
  }

  Widget _buildRoleCard(CollaborationRole role,
      CollaborationRequest collaboration, bool canApply) {
    final isFilled = role.status == 'filled';
    final isOpen = role.status == 'open';
    final assignedCount = role.assignedArtisanIds.length;
    final maxCount = role.maxArtisans;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFilled
              ? successColor.withOpacity(0.3)
              : isOpen
                  ? primaryColor.withOpacity(0.3)
                  : const Color.fromARGB(255, 89, 176, 70).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.handyman, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  role.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
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
              color: primaryColor.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildRoleMetric(
                      'Budget', '₹${role.allocatedBudget.toStringAsFixed(0)}'),
                ),
                Container(
                    height: 30, width: 1, color: primaryColor.withOpacity(0.3)),
                Expanded(
                  child:
                      _buildRoleMetric('Artisans', '$assignedCount/$maxCount'),
                ),
                Container(
                    height: 30, width: 1, color: primaryColor.withOpacity(0.3)),
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
                color: successColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: successColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, color: successColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned Members ($assignedCount)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...role.assignedArtisanIds.take(3).map(
                        (memberId) => FutureBuilder<Map<String, dynamic>?>(
                          future: _getMemberInfo(memberId),
                          builder: (context, snapshot) {
                            final memberInfo = snapshot.data;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: successColor,
                                    child: Text(
                                      (memberInfo?['name'] ?? 'U')[0]
                                          .toUpperCase(),
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
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.check_circle,
                                      color: successColor, size: 16),
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
                        color: successColor,
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
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: primaryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          skill,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primaryColor,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],

          // Application status and apply button
          StreamBuilder<List<CollaborationApplication>>(
            stream: _collaborationService
                .getCollaborationApplications(collaboration.id),
            builder: (context, snapshot) {
              final applications = snapshot.data ?? [];
              final currentUser = FirebaseAuth.instance.currentUser;

              final hasAppliedForThisRole = applications.any((app) =>
                  app.artisanId == currentUser?.uid && app.roleId == role.id);

              final pendingApplication = applications.firstWhere(
                (app) =>
                    app.artisanId == currentUser?.uid &&
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

              final acceptedApplication = applications.firstWhere(
                (app) =>
                    app.artisanId == currentUser?.uid &&
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
              final isRoleFull = assignedCount >= maxCount;

              if (canApply && !isRoleFull && !hasAppliedForThisRole) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _applyForRole(role, collaboration),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.handyman, size: 18),
                        label: Text(
                          'Apply for this Role',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                );
              } else if (hasPendingApplication) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_empty,
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
                                  'Your application is being reviewed',
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
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: successColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: successColor, size: 20),
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
                                    color: successColor,
                                  ),
                                ),
                                Text(
                                  'You are now part of this project',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: successColor,
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

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCommunicationSection(CollaborationRequest collaboration) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLeader = currentUser?.uid == collaboration.leadArtisanId;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.chat, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Team Communication',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Team Chat Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openTeamChat(collaboration),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: cardColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.group, size: 18),
              label: Text(
                'Open Team Chat',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Chat with team members:',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),

          // Chat with project leader (if current user is not the leader)
          if (!isLeader)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _openDirectChatWithLeader(collaboration),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: warningColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: warningColor,
                        child: const Icon(Icons.star,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project Leader',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              'Chat with your project leader',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: primaryColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chat_bubble_outline,
                          color: primaryColor, size: 16),
                    ],
                  ),
                ),
              ),
            ),

          // Chat with other collaborators
          ...collaboration.collaboratorIds
              .where((memberId) => memberId != currentUser?.uid)
              .map(
                (memberId) => FutureBuilder<Map<String, dynamic>?>(
                  future: _getMemberInfo(memberId),
                  builder: (context, snapshot) {
                    final memberInfo = snapshot.data;
                    if (memberInfo == null) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _openDirectChat(
                            collaboration, memberId, memberInfo['name']),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: primaryColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: primaryColor,
                                child: Text(
                                  memberInfo['name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      memberInfo['name'],
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Team Member',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: primaryColor.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chat_bubble_outline,
                                  color: primaryColor, size: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
        color = successColor;
        label = 'Filled';
        icon = Icons.check_circle;
        break;
      case 'open':
        color = const Color.fromARGB(255, 130, 200, 116);
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
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: primaryColor.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
              color: primaryColor,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: primaryColor.withOpacity(0.7),
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
                color: primaryColor.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(CollaborationApplication application) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            application.proposal,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: primaryColor.withOpacity(0.8),
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
                  color: successColor,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Timeline: ${application.estimatedDays} days',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
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
                    onPressed: () =>
                        _updateApplicationStatus(application.id, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: successColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _updateApplicationStatus(application.id, 'rejected'),
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

  // Helper methods for user info and formatting
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

  void _applyForRole(
      CollaborationRole role, CollaborationRequest collaboration) {
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

  Future<void> _updateApplicationStatus(
      String applicationId, String status) async {
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
            backgroundColor:
                status == 'accepted' ? successColor : Colors.orange,
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

  void _openDirectChatWithLeader(CollaborationRequest collaboration) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final List<String> userIds = [currentUser.uid, collaboration.leadArtisanId];
    userIds.sort();
    final directChatRoomId =
        'direct_${collaboration.id}_${userIds[0]}_${userIds[1]}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollaborationChatScreen(
          collaborationId: collaboration.id,
          chatRoomId: directChatRoomId,
          chatType: 'direct',
          collaboration: collaboration,
          currentUserName: _getCurrentUserName(),
          otherUserName: 'Project Leader',
          otherUserId: collaboration.leadArtisanId,
        ),
      ),
    );
  }

  void _openTeamChat(CollaborationRequest collaboration) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final teamChatRoomId = 'team_${collaboration.id}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollaborationChatScreen(
          collaborationId: collaboration.id,
          chatRoomId: teamChatRoomId,
          chatType: 'team',
          collaboration: collaboration,
          currentUserName: _getCurrentUserName(),
        ),
      ),
    );
  }

  void _openDirectChat(
      CollaborationRequest collaboration, String memberId, String memberName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final List<String> userIds = [currentUser.uid, memberId];
    userIds.sort();
    final directChatRoomId =
        'direct_${collaboration.id}_${userIds[0]}_${userIds[1]}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollaborationChatScreen(
          collaborationId: collaboration.id,
          chatRoomId: directChatRoomId,
          chatType: 'direct',
          collaboration: collaboration,
          currentUserName: _getCurrentUserName(),
          otherUserName: memberName,
          otherUserId: memberId,
        ),
      ),
    );
  }

  String _getCurrentUserName() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.displayName ??
        currentUser?.email?.split('@')[0] ??
        'User';
  }

  void _navigateToEditScreen(CollaborationRequest collaboration) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProjectScreen(collaboration: collaboration),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Project updated successfully'),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showStatusUpdateDialog(CollaborationRequest collaboration) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.update, color: primaryColor, size: 24),
            const SizedBox(width: 12),
            Text(
              'Update Project Status',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status: ${_getStatusDisplayText(collaboration.status)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _getStatusColor(collaboration.status),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select new status:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...['open', 'in_progress', 'on_hold', 'completed', 'cancelled'].map(
              (status) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _updateProjectStatus(collaboration.id, status),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: collaboration.status == status
                          ? _getStatusColor(status).withOpacity(0.1)
                          : backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: collaboration.status == status
                            ? _getStatusColor(status).withOpacity(0.3)
                            : primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusDisplayText(status),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(status),
                                ),
                              ),
                              Text(
                                _getStatusDescription(status),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: primaryColor.withOpacity(0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (collaboration.status == status)
                          Icon(
                            Icons.check_circle,
                            color: _getStatusColor(status),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProjectStatus(String projectId, String newStatus) async {
    try {
      Navigator.pop(context); // Close dialog
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(projectId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: cardColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                    'Project status updated to ${_getStatusDisplayText(newStatus)}'),
              ],
            ),
            backgroundColor: _getStatusColor(newStatus),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Error updating status: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProjectStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 14,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 6),
          Text(
            _getStatusDisplayText(status),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(status),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return secondaryColor;
      case 'in_progress':
      case 'in-progress':
        return inProgressColor;
      case 'completed':
        return completedColor;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      case 'on_hold':
      case 'on-hold':
        return warningColor;
      case 'draft':
        return Colors.grey;
      default:
        return primaryColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.radio_button_checked;
      case 'in_progress':
      case 'in-progress':
        return Icons.work_outline;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel;
      case 'on_hold':
      case 'on-hold':
        return Icons.pause_circle;
      case 'draft':
        return Icons.description;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Open for Applications';
      case 'in_progress':
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'on_hold':
      case 'on-hold':
        return 'On Hold';
      case 'draft':
        return 'Draft';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'This project is actively accepting applications from artisans. Team members can apply for available roles.';
      case 'in_progress':
      case 'in-progress':
        return 'Work has begun on this project. Team members are actively working on their assigned tasks and roles.';
      case 'completed':
        return 'This project has been successfully completed. All deliverables have been finished and approved.';
      case 'cancelled':
      case 'canceled':
        return 'This project has been cancelled and is no longer active. No further work will be done.';
      case 'on_hold':
      case 'on-hold':
        return 'This project is temporarily paused. Work may resume at a later date based on project requirements.';
      case 'draft':
        return 'This project is still being planned and is not yet ready for team member applications.';
      default:
        return 'Current project status and progress information.';
    }
  }
}
