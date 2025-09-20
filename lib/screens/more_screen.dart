import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'faq/buyer_faq_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color.fromARGB(255, 93, 64, 55);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Help & Support'),
          _buildMenuItem(
            context: context,
            icon: Icons.help_outline,
            title: 'FAQ & Help Center',
            subtitle: 'Find answers to frequently asked questions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BuyerFAQScreen()),
              );
            },
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.support_agent,
            title: 'Contact Support',
            subtitle: 'Get help from our support team',
            onTap: () {
              // TODO: Implement contact support
            },
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.bug_report_outlined,
            title: 'Report a Problem',
            subtitle: 'Report bugs or issues with the app',
            onTap: () {
              // TODO: Implement bug reporting
            },
          ),
          SizedBox(height: 24),
          _buildSectionHeader('Account & Settings'),
          _buildMenuItem(
            context: context,
            icon: Icons.settings_outlined,
            title: 'App Settings',
            subtitle: 'Customize your app experience',
            onTap: () {
              // TODO: Implement settings
            },
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Learn about our privacy practices',
            onTap: () {
              // TODO: Implement privacy policy
            },
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
            onTap: () {
              // TODO: Implement terms of service
            },
          ),
          SizedBox(height: 24),
          _buildSectionHeader('About'),
          _buildMenuItem(
            context: context,
            icon: Icons.info_outline,
            title: 'About Arti',
            subtitle: 'Learn more about our marketplace',
            onTap: () {
              // TODO: Implement about page
            },
          ),
          _buildMenuItem(
            context: context,
            icon: Icons.star_rate_outlined,
            title: 'Rate the App',
            subtitle: 'Share your feedback on the app store',
            onTap: () {
              // TODO: Implement app rating
            },
          ),
          SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  'Arti Marketplace',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final Color primaryColor = Color.fromARGB(255, 93, 64, 55);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
