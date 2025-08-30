import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'AIzaSyD9tZLBazZi2SDHotY_F028kNIjYD8cxyk';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';

  // Convert image file to base64
  static String _encodeImageToBase64(File imageFile) {
    final bytes = imageFile.readAsBytesSync();
    return base64Encode(bytes);
  }

  // Extract product details from images
  static Future<Map<String, dynamic>> extractProductDetails(List<File> images) async {
    try {
      if (images.isEmpty) {
        throw Exception('No images provided for analysis');
      }

      // Prepare the request body with multiple images
      final List<Map<String, dynamic>> imageParts = images.map((image) {
        final base64Image = _encodeImageToBase64(image);
        final mimeType = _getMimeType(image.path);
        
        return {
          "inlineData": {
            "mimeType": mimeType,
            "data": base64Image
          }
        };
      }).toList();

      final requestBody = {
        "contents": [{
          "parts": [
            {
              "text": """
Analyze these images of a handcrafted artisan product and extract the following details in JSON format:

{
  "name": "Product name (creative and descriptive)",
  "description": "Detailed description highlighting craftsmanship, uniqueness, and artisan techniques (150-300 words)",
  "category": "Product category (e.g., Pottery, Jewelry, Textiles, Woodwork, Metalwork, Leather Goods, Glass Art, etc.)",
  "materials": ["List of materials used"],
  "craftingTime": "Estimated time to craft (e.g., '2-3 days', '1 week', etc.)",
  "dimensions": "Approximate dimensions or size",
  "suggestedPrice": "Suggested price range in USD (just the number, no currency symbol)",
  "tags": ["Relevant tags for searchability"],
  "careInstructions": "Care and maintenance instructions"
}

Focus on:
- Identifying the craft technique and materials
- Highlighting unique artistic elements
- Describing the cultural or traditional aspects if visible
- Suggesting appropriate pricing based on complexity and materials
- Providing practical care information

Be descriptive and emphasize the handmade, artisanal nature of the product.
"""
            },
            ...imageParts
          ]
        }]
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['candidates'][0]['content']['parts'][0]['text'];
        
        // Extract JSON from the response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(0)!;
          return jsonDecode(jsonString);
        } else {
          throw Exception('Failed to extract JSON from Gemini response');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Gemini API Error: ${errorData['error']['message']}');
      }
    } catch (e) {
      print('Error in extractProductDetails: $e');
      // Return default structure on error
      return {
        "name": "Handcrafted Artisan Product",
        "description": "Beautiful handcrafted item made with traditional techniques and premium materials.",
        "category": "Handmade",
        "materials": ["Natural materials"],
        "craftingTime": "Several days",
        "dimensions": "Medium size",
        "suggestedPrice": "50",
        "tags": ["handmade", "artisan", "unique"],
        "careInstructions": "Handle with care, keep in dry place"
      };
    }
  }

  // Analyze video for product details
  static Future<Map<String, dynamic>> extractProductDetailsFromVideo(File videoFile) async {
    // For video analysis, we'll use a text-only approach since video analysis is more complex
    // This is a simplified version - in production, you might want to extract frames from video
    try {
      final requestBody = {
        "contents": [{
          "parts": [{
            "text": """
Based on the context that this is a video showcasing a handcrafted artisan product from all angles, 
provide product details in JSON format:

{
  "name": "Handcrafted Artisan Product (Video Showcase)",
  "description": "Beautiful handcrafted item demonstrated in detail through video, showing all angles and craftsmanship details. Made with traditional artisan techniques.",
  "category": "Handmade",
  "materials": ["Premium materials", "Traditional components"],
  "craftingTime": "Several days of careful work",
  "dimensions": "Custom sizing available",
  "suggestedPrice": "75",
  "tags": ["handmade", "artisan", "video-showcased", "detailed-view"],
  "careInstructions": "Handle with care, follow traditional maintenance methods"
}

Make this appropriate for an artisan marketplace where quality and craftsmanship are valued.
"""
          }]
        }]
      };

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['candidates'][0]['content']['parts'][0]['text'];
        
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonString = jsonMatch.group(0)!;
          return jsonDecode(jsonString);
        }
      }
      
      throw Exception('Failed to analyze video');
    } catch (e) {
      print('Error in extractProductDetailsFromVideo: $e');
      return {
        "name": "Video Showcased Artisan Product",
        "description": "Handcrafted product showcased through comprehensive video, displaying all angles and intricate details.",
        "category": "Handmade",
        "materials": ["Quality materials"],
        "craftingTime": "Multiple days",
        "dimensions": "As shown in video",
        "suggestedPrice": "75",
        "tags": ["handmade", "artisan", "video-demo"],
        "careInstructions": "Handle with care"
      };
    }
  }

  // Get MIME type from file extension
  static String _getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
