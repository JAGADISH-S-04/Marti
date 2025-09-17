import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/collab_service.dart';
import '../../models/collab_model.dart';
import 'collaboration_details_screen.dart';
import 'create_collaboration_screen.dart';

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Collaboration Projects',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2C1810),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(text: 'My Projects', icon: Icon(Icons.person)),
            Tab(text: 'Available', icon: Icon(Icons.search)),
            Tab(text: 'Participating', icon: Icon(Icons.group)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCollaborationDialog(),
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('New Collaboration'),
      ),
    );
  }

  Widget _buildMyProjectsTab() {
    return StreamBuilder<List<CollaborationRequest>>(
      stream: _collaborationService.getMyLeadCollaborations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return _buildEmptyState(
            'No Projects Yet',
            'Create your first collaboration project to work with other artisans',
            Icons.group_work,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            return _buildProjectCard(projects[index], isLeader: true);
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final projects = snapshot.data ?? [];
        final currentUser = FirebaseAuth.instance.currentUser;

        // Filter out projects where user is already the lead or collaborator
        final availableProjects = projects.where((project) {
          return project.leadArtisanId != currentUser?.uid &&
              !project.collaboratorIds.contains(currentUser?.uid) &&
              project.status == 'open'; // Only show open projects
        }).toList();

        if (availableProjects.isEmpty) {
          return _buildEmptyState(
            'No Available Projects',
            'Check back later for new collaboration opportunities from fellow artisans',
            Icons.search,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableProjects.length,
          itemBuilder: (context, index) {
            return _buildProjectCard(availableProjects[index], isLeader: false);
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return _buildEmptyState(
            'No Collaborations Yet',
            'Join collaboration projects to work with other artisans',
            Icons.group,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            return _buildProjectCard(projects[index], isLeader: false);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(CollaborationRequest project,
      {required bool isLeader}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToProjectDetails(project),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(project.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _getStatusColor(project.status)),
                    ),
                    child: Text(
                      project.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(project.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                project.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Project info
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Budget',
                      '₹${project.totalBudget.toStringAsFixed(0)}',
                      Icons.account_balance_wallet,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      'Roles',
                      '${project.requiredRoles.length} roles',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Collaborators and deadline
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      'Team',
                      '${project.collaboratorIds.length + 1} members',
                      Icons.group,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoChip(
                      'Deadline',
                      _formatDeadline(project.deadline),
                      Icons.schedule,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Role tags
              if (project.requiredRoles.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: project.requiredRoles.take(3).map((role) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C1810),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              Row(
                children: [
                  if (isLeader) ...[
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    const Text(
                      'Project Leader',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.group_work, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Text(
                      'Collaborator',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => _navigateToProjectDetails(project),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 7) {
      return '$difference days';
    } else {
      return '${(difference / 7).floor()} weeks';
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
        title: const Text('Create New Collaboration'),
        content: const Text(
          'To create a collaboration project, you need to have an accepted craft request. '
          'Please go to your accepted requests and open one for collaboration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
