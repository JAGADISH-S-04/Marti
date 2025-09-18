import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/collab_service.dart';
import '../../models/collab_model.dart';
import '../craft_it/seller_view.dart';
import 'collaboration_management_screen.dart';
import 'collaboration_details_screen.dart';

class SellerCollaborationScreen extends StatefulWidget {
  const SellerCollaborationScreen({Key? key}) : super(key: key);

  @override
  State<SellerCollaborationScreen> createState() =>
      _SellerCollaborationScreenState();
}

class _SellerCollaborationScreenState extends State<SellerCollaborationScreen> {
  final CollaborationService _collaborationService = CollaborationService();

  // Craftwork-themed colors
  final Color craftBrown = const Color(0xFF8B4513);
  final Color craftGold = const Color(0xFFD4AF37);
  final Color craftBeige = const Color(0xFFF5F5DC);
  final Color craftDarkBrown = const Color(0xFF5D2E0A);
  final Color craftLightBrown = const Color(0xFFDEB887);

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
          'Artisan Collaboration Hub',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.view_list, color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CollaborationManagementScreen(),
                ),
              );
            },
            tooltip: 'View All Collaborations',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, craftBeige.withOpacity(0.5)],
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
                border:
                    Border.all(color: craftGold.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [craftGold, craftGold.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: craftGold.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.handyman,
                          size: 32,
                          color: craftDarkBrown,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, Master Artisan!',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: craftDarkBrown,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Collaborate with fellow craftspeople to create extraordinary pieces together',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: craftBrown.withOpacity(0.8),
                                height: 1.4,
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

            const SizedBox(height: 30),

            // Quick Actions
            Text(
              'Quick Actions',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: craftDarkBrown,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'Browse Projects',
                    'Discover collaboration opportunities',
                    Icons.search,
                    craftBrown,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CollaborationManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    'My Requests',
                    'Manage craft requests',
                    Icons.assignment,
                    const Color(0xFF228B22),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SellerRequestsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // My Active Collaborations
            Text(
              'My Active Collaborations',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: craftDarkBrown,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<CollaborationRequest>>(
              stream: _collaborationService.getMyLeadCollaborations(),
              builder: (context, leadSnapshot) {
                if (leadSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(craftGold),
                      ),
                    ),
                  );
                }

                final leadProjects = leadSnapshot.data ?? [];

                return StreamBuilder<List<CollaborationRequest>>(
                  stream: _collaborationService.getMyCollaborations(),
                  builder: (context, memberSnapshot) {
                    if (memberSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(craftGold),
                          ),
                        ),
                      );
                    }

                    final memberProjects = memberSnapshot.data ?? [];
                    final allActiveProjects = [
                      ...leadProjects,
                      ...memberProjects
                    ];

                    if (allActiveProjects.isEmpty) {
                      return _buildEmptyCollaborationsCard();
                    }

                    return Column(
                      children: allActiveProjects
                          .map((project) => _buildCollaborationCard(
                                project,
                                leadProjects.contains(project),
                              ))
                          .toList(),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),

            // Available Opportunities
            Text(
              'Available Craft Opportunities',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: craftDarkBrown,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<CollaborationRequest>>(
              stream: _collaborationService.getOpenCollaborationRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(craftGold),
                      ),
                    ),
                  );
                }

                final allProjects = snapshot.data ?? [];
                final currentUser = FirebaseAuth.instance.currentUser;

                // Filter available projects
                final availableProjects = allProjects.where((project) {
                  final isNotLeader = project.leadArtisanId != currentUser?.uid;
                  final isNotMember =
                      !project.collaboratorIds.contains(currentUser?.uid);
                  final isOpen = project.status == 'open';
                  final hasOpenRoles = project.requiredRoles
                      .any((role) => role.status == 'open');

                  return isNotLeader && isNotMember && isOpen && hasOpenRoles;
                }).toList();

                if (availableProjects.isEmpty) {
                  return _buildNoOpportunitiesCard();
                }

                // Show only first 3 opportunities
                final displayProjects = availableProjects.take(3).toList();

                return Column(
                  children: [
                    ...displayProjects
                        .map((project) => _buildOpportunityCard(project)),
                    if (availableProjects.length > 3) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CollaborationManagementScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: craftBrown,
                            backgroundColor: craftBeige,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          icon: const Icon(Icons.visibility),
                          label: Text(
                            'View All ${availableProjects.length} Opportunities',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: craftDarkBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: craftBrown.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCollaborationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: craftLightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: craftBrown.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: craftBeige.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_work_outlined,
              size: 48,
              color: craftBrown,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Active Collaborations',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: craftDarkBrown,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Start collaborating by opening your accepted requests for collaboration or browse available craft projects from fellow artisans',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: craftBrown.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CollaborationManagementScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: craftGold,
              foregroundColor: craftDarkBrown,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.search),
            label: Text(
              'Browse Craft Projects',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOpportunitiesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: craftLightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: craftBrown.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: craftBeige.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: craftBrown,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Opportunities Available',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: craftDarkBrown,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'New collaboration projects from fellow artisans will appear here. Check back soon for exciting craft opportunities!',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: craftBrown.withOpacity(0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationCard(CollaborationRequest project, bool isLeader) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            isLeader
                ? craftGold.withOpacity(0.05)
                : craftBeige.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLeader
              ? craftGold.withOpacity(0.5)
              : craftLightBrown.withOpacity(0.5),
          width: isLeader ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: craftBrown.withOpacity(0.1),
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
              if (isLeader) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [craftGold, craftGold.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: craftDarkBrown),
                      const SizedBox(width: 4),
                      Text(
                        'LEADER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: craftDarkBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  project.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: craftDarkBrown,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(project.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _getStatusColor(project.status).withOpacity(0.5)),
                ),
                child: Text(
                  _getStatusText(project.status),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(project.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            project.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: craftBrown.withOpacity(0.8),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.currency_rupee,
                  size: 16, color: const Color(0xFF228B22)),
              const SizedBox(width: 4),
              Text(
                '₹${_formatCurrency(project.totalBudget)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF228B22),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.group, size: 16, color: craftBrown),
              const SizedBox(width: 4),
              Text(
                '${project.collaboratorIds.length + 1} artisans',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: craftBrown,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CollaborationDetailsScreen(
                        collaboration: project,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: craftBrown,
                  backgroundColor: craftBeige,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(CollaborationRequest project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Expanded(
                child: Text(
                  project.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: craftDarkBrown,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF228B22).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF228B22).withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open,
                        size: 12, color: const Color(0xFF228B22)),
                    const SizedBox(width: 4),
                    Text(
                      'OPEN',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF228B22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            project.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: craftBrown.withOpacity(0.8),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.currency_rupee,
                  size: 16, color: const Color(0xFF228B22)),
              const SizedBox(width: 4),
              Text(
                '₹${_formatCurrency(project.totalBudget)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF228B22),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.people, size: 16, color: craftBrown),
              const SizedBox(width: 4),
              Text(
                '${project.requiredRoles.where((r) => r.status == 'open').length} open roles',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: craftBrown,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CollaborationDetailsScreen(
                        collaboration: project,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: craftGold,
                  foregroundColor: craftDarkBrown,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Join Craft',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF228B22);
      case 'in_progress':
        return const Color(0xFF4169E1);
      case 'completed':
        return const Color(0xFF8B008B);
      case 'cancelled':
        return Colors.red;
      default:
        return craftBrown;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'OPEN';
      case 'in_progress':
        return 'CRAFTING';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'PAUSED';
      default:
        return status.toUpperCase();
    }
  }
}
