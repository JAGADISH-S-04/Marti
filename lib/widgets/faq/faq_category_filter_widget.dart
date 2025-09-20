import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/faq.dart';

class FAQCategoryFilterWidget extends StatelessWidget {
  final List<FAQCategory> categories;
  final FAQCategory? selectedCategory;
  final Function(FAQCategory?) onCategorySelected;
  final UserType userType;

  const FAQCategoryFilterWidget({
    Key? key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.userType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color.fromARGB(255, 93, 64, 55);

    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" option
            final isSelected = selectedCategory == null;
            return _buildCategoryChip(
              label: 'All',
              icon: Icons.grid_view,
              isSelected: isSelected,
              onTap: () => onCategorySelected(null),
              primaryColor: primaryColor,
            );
          }

          final category = categories[index - 1];
          final isSelected = selectedCategory == category;

          return _buildCategoryChip(
            label: category.displayName,
            icon: _getCategoryIcon(category),
            isSelected: isSelected,
            onTap: () => onCategorySelected(category),
            primaryColor: primaryColor,
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(FAQCategory category) {
    switch (category) {
      case FAQCategory.account:
        return Icons.person_outline;
      case FAQCategory.orders:
        return Icons.shopping_bag_outlined;
      case FAQCategory.payments:
        return Icons.payment;
      case FAQCategory.products:
        return Icons.inventory_2_outlined;
      case FAQCategory.shipping:
        return Icons.local_shipping_outlined;
      case FAQCategory.returns:
        return Icons.keyboard_return;
      case FAQCategory.technical:
        return Icons.build_outlined;
      case FAQCategory.onboarding:
        return Icons.rocket_launch_outlined;
      case FAQCategory.commissions:
        return Icons.monetization_on_outlined;
      case FAQCategory.inventory:
        return Icons.warehouse_outlined;
      case FAQCategory.analytics:
        return Icons.analytics_outlined;
      case FAQCategory.communication:
        return Icons.chat_outlined;
      case FAQCategory.verification:
        return Icons.verified_outlined;
      case FAQCategory.general:
        return Icons.help_outline;
    }
  }
}
