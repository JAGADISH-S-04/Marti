import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:arti/models/product.dart';
import 'package:arti/screens/product_detail_screen.dart';
import 'package:arti/screens/product_reviews_management_screen.dart';

class ProductManagementScreen extends StatelessWidget {
  final Product product;
  final Map<String, dynamic> productData;
  final VoidCallback? onEdit;
  final VoidCallback? onViewReviews;

  const ProductManagementScreen({
    Key? key,
    required this.product,
    required this.productData,
    this.onEdit,
    this.onViewReviews,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formattedPrice = NumberFormat.decimalPattern('en_IN').format(product.price);
    
    // Check if product has AI-enhanced image
    final Map<String, dynamic>? aiAnalysis = productData['aiAnalysis'] as Map<String, dynamic>?;
    final String? aiEnhancedImageUrl = aiAnalysis?['aiEnhancedImageUrl'] as String?;
    final bool hasAiImage = aiEnhancedImageUrl != null && aiEnhancedImageUrl.isNotEmpty;
    final String? currentDisplayImage = productData['imageUrl'] as String?;
    final bool isShowingAiImage = hasAiImage && currentDisplayImage == aiEnhancedImageUrl;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Product Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Product Header Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Product Image
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      image: currentDisplayImage != null
                          ? DecorationImage(
                              image: NetworkImage(currentDisplayImage),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        if (currentDisplayImage == null)
                          const Center(
                            child: Icon(Icons.image_not_supported, 
                                size: 40, color: Colors.grey),
                          ),
                        // AI badge indicator
                        if (isShowingAiImage)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Product Info
                  Text(
                    product.name,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    product.category,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    '₹$formattedPrice',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        icon: Icons.visibility_outlined,
                        label: 'Views',
                        value: '${productData['views'] ?? 0}',
                        color: Colors.blue,
                      ),
                      _buildStatItem(
                        icon: Icons.favorite_outline,
                        label: 'Likes',
                        value: '${productData['likes'] ?? 0}',
                        color: Colors.red,
                      ),
                      _buildStatItem(
                        icon: Icons.rate_review_outlined,
                        label: 'Reviews',
                        value: '${productData['reviewCount'] ?? 0}',
                        color: Colors.orange,
                      ),
                      _buildStatItem(
                        icon: Icons.inventory_outlined,
                        label: 'Stock',
                        value: '${productData['stockQuantity'] ?? 0}',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Cards
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Preview Card
                  _buildActionCard(
                    context: context,
                    icon: Icons.visibility_outlined,
                    iconColor: Colors.blue,
                    title: 'View Product Preview',
                    subtitle: 'See how customers view your product',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(
                            product: product, 
                            isSellerView: true,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Review Management Card
                  _buildActionCard(
                    context: context,
                    icon: Icons.rate_review_outlined,
                    iconColor: Colors.orange,
                    title: 'Manage Reviews',
                    subtitle: '${productData['reviewCount'] ?? 0} reviews • Reply to customers',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductReviewsManagementScreen(
                            product: product,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Edit Product Card
                  _buildActionCard(
                    context: context,
                    icon: Icons.edit_outlined,
                    iconColor: Colors.green,
                    title: 'Edit Product',
                    subtitle: 'Update product details, images, and pricing',
                    onTap: () {
                      Navigator.pop(context);
                      if (onEdit != null) onEdit!();
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Analytics Card
                  _buildActionCard(
                    context: context,
                    icon: Icons.analytics_outlined,
                    iconColor: Colors.purple,
                    title: 'Product Analytics',
                    subtitle: 'Performance insights and trends',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analytics feature coming soon!'),
                          backgroundColor: Colors.purple,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}