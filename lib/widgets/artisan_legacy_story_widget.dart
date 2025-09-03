import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
// For the maps integration, you would need to add google_maps_flutter package
// import 'package:google_maps_flutter/google_maps_flutter.dart';

class ArtisanLegacyStoryWidget extends StatelessWidget {
  final Product product;

  const ArtisanLegacyStoryWidget({Key? key, required this.product})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (product.artisanLegacyStory == null ||
        product.provenanceMapData == null) {
      return const SizedBox.shrink(); // Don't show if there's no story
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF9F6F2),
            const Color(0xFFF9F6F2).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: Color(0xFF8B6914),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Artisan's Legacy",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2)),
            ),
            child: Text(
              product.artisanLegacyStory!,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.7,
                color: const Color(0xFF2C1810).withOpacity(0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6914).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF8B6914),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "The Product's Journey",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C1810),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Interactive Map Placeholder or Journey Points
          _buildJourneyPoints(),
        ],
      ),
    );
  }

  Widget _buildJourneyPoints() {
    final mapData = product.provenanceMapData;
    if (mapData == null || mapData['points'] == null) {
      return _buildMapPlaceholder();
    }

    final points = mapData['points'] as List;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // For now, show journey points as cards instead of map
          ...points.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value as Map<String, dynamic>;
            return _buildJourneyPointCard(point, index, points.length);
          }).toList(),
          
          const SizedBox(height: 12),
          
          // Future: Interactive Map Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B6914).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8B6914).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map,
                  color: Color(0xFF8B6914),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Interactive Map Coming Soon',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8B6914),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyPointCard(Map<String, dynamic> point, int index, int total) {
    return Container(
      margin: EdgeInsets.only(bottom: index < total - 1 ? 16 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6914),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (index < total - 1)
                Container(
                  width: 2,
                  height: 40,
                  color: const Color(0xFF8B6914).withOpacity(0.3),
                ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // Point information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point['title'] ?? 'Location ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  point['snippet'] ?? 'Part of the journey...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF2C1810).withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                if (point['lat'] != null && point['lng'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Location: ${point['lat']?.toStringAsFixed(4)}, ${point['lng']?.toStringAsFixed(4)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF8B6914),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Interactive Map Placeholder',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Journey points will be shown here',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
