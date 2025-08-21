import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SellerScreen extends StatelessWidget {
  const SellerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Rich Top Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.store,
                            color: Color(0xFFD4AF37),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seller Dashboard',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Manage your artisan business',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'My Store',
                              Icons.storefront,
                              () {
                                // Navigate to My Store
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('My Store - Coming Soon')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              context,
                              'List My Store',
                              Icons.add_business,
                              () {
                                // Navigate to List Store
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('List My Store - Coming Soon')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          context,
                          'Product Listing',
                          Icons.inventory_2,
                          () {
                            // Navigate to Product Listing
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Product Listing - Coming Soon')),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Stats Cards
                      Text(
                        'Overview',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Total Products',
                              '0',
                              Icons.inventory,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Total Sales',
                              '₹0',
                              Icons.attach_money,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Orders',
                              '0',
                              Icons.shopping_bag,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatsCard(
                              context,
                              'Reviews',
                              '0',
                              Icons.star,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 100,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.all(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
