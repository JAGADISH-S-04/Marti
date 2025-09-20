import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/faq_service.dart';
import '../../services/admin_service.dart';
import 'faq_management_screen.dart';

class FAQDataInitializerScreen extends StatefulWidget {
  const FAQDataInitializerScreen({Key? key}) : super(key: key);

  @override
  State<FAQDataInitializerScreen> createState() =>
      _FAQDataInitializerScreenState();
}

class _FAQDataInitializerScreenState extends State<FAQDataInitializerScreen> {
  bool _isInitializing = false;
  String _status = '';

  final Color primaryColor = const Color.fromARGB(255, 93, 64, 55);

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    if (!await AdminService.hasAdminAccess('faq_management')) {
      if (mounted) {
        AdminService.showAdminAccessDeniedDialog(context);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'FAQ Data Setup',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.help_center,
              size: 80,
              color: primaryColor.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'FAQ System Setup',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Initialize your FAQ system with sample data or start fresh with the management interface.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (_status.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.contains('Error')
                      ? Colors.red[50]
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _status.contains('Error')
                        ? Colors.red[200]!
                        : Colors.green[200]!,
                  ),
                ),
                child: Text(
                  _status,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _status.contains('Error')
                        ? Colors.red[700]
                        : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
            _buildActionCard(
              'Initialize Sample Data',
              'Add pre-built FAQs for customers and retailers',
              Icons.rocket_launch,
              Colors.blue,
              _isInitializing ? null : _initializeSampleData,
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              'Open FAQ Management',
              'Manage FAQs with full admin interface',
              Icons.admin_panel_settings,
              Colors.purple,
              () => _openFAQManagement(),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              'View FAQ Statistics',
              'Check current FAQ data and usage stats',
              Icons.analytics,
              Colors.orange,
              () => _showStatistics(),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              'Check Admin Status',
              'Verify your admin access and permissions',
              Icons.verified_user,
              Colors.blue,
              () => _checkCurrentUserAdmin(),
            ),
            const Spacer(),
            if (_isInitializing)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Initializing FAQ data...',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeSampleData() async {
    setState(() {
      _isInitializing = true;
      _status = '';
    });

    try {
      await FAQService.initializeDefaultFAQs();
      setState(() {
        _status = 'Success! Sample FAQ data has been initialized.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: Failed to initialize FAQ data. ${e.toString()}';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _openFAQManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FAQManagementScreen(),
      ),
    );
  }

  Future<void> _showStatistics() async {
    try {
      final stats = await FAQService.getFAQStatistics();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'FAQ Statistics',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                  'Total FAQs', stats['totalFAQs']?.toString() ?? '0'),
              _buildStatRow(
                  'Customer FAQs', stats['customerFAQs']?.toString() ?? '0'),
              _buildStatRow(
                  'Retailer FAQs', stats['retailerFAQs']?.toString() ?? '0'),
              _buildStatRow(
                  'Total Views', stats['totalViews']?.toString() ?? '0'),
              _buildStatRow(
                  'Total Helpful', stats['totalHelpful']?.toString() ?? '0'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _status = 'Error fetching statistics: ${e.toString()}';
      });
    }
  }

  Future<void> _checkCurrentUserAdmin() async {
    try {
      final isAdmin = await AdminService.isCurrentUserAdmin();
      final hasFAQAccess = await AdminService.hasAdminAccess('faq_management');
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Admin Status Check',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusRow('User Email', user?.email ?? 'Not logged in'),
              _buildStatusRow('User ID', user?.uid ?? 'N/A'),
              _buildStatusRow('Admin Status', isAdmin ? 'YES ✅' : 'NO ❌'),
              _buildStatusRow(
                  'FAQ Management Access', hasFAQAccess ? 'YES ✅' : 'NO ❌'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _status = 'Error checking admin status: ${e.toString()}';
      });
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
