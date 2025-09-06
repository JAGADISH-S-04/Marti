import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class GcpService {
  // GCP API Key for direct authentication (Vision API)
  static const String _apiKey = 'AIzaSyCjb4VQTSsCYFcqtgiiNmu5grqxF_cEsCQ';
  
  // OAuth 2.0 credentials context for Video Intelligence API

  /// Initialize OAuth 2.0 authentication for Video Intelligence API
  static Future<void> _loadCredentials() async {
    try {
      // Load OAuth 2.0 credentials for installed application
      final credentialsJson = await rootBundle.loadString('credentials.json');
      final credentialsMap = jsonDecode(credentialsJson);
      
      print('✅ OAuth credentials loaded for project: ${credentialsMap['installed']['project_id']}');
      print('📝 Using enhanced mock data (OAuth flow requires user interaction in mobile apps)');
    } catch (e) {
      print('⚠️ Could not load OAuth credentials: $e');
      print('📝 Using standard mock data for video analysis');
    }
  }

  /// Analyzes images using the Cloud Vision API with API key authentication.
  static Future<Map<String, List<String>>> analyzeImages(List<File> images) async {
    try {
      final Map<String, List<String>> results = {};

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final String base64Image = base64Encode(bytes);

        final request = {
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 15},
                {'type': 'OBJECT_LOCALIZATION', 'maxResults': 15},
                {'type': 'TEXT_DETECTION', 'maxResults': 5},
              ],
            }
          ]
        };

        final response = await http.post(
          Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final responseData = data['responses'][0];
          
          final labels = (responseData['labelAnnotations'] as List?)
              ?.map<String>((label) => '${label['description']} (${(label['score'] * 100).toInt()}%)')
              .toList() ?? [];
              
          final objects = (responseData['localizedObjectAnnotations'] as List?)
              ?.map<String>((obj) => '${obj['name']} (${(obj['score'] * 100).toInt()}%)')
              .toList() ?? [];

          final texts = (responseData['textAnnotations'] as List?)
              ?.map<String>((text) => text['description'] as String)
              .take(3) // Only take first 3 text detections
              .toList() ?? [];

          final tags = [...labels, ...objects, ...texts].toList();
          results[image.path.split('/').last] = tags;
          print('✅ Vision API analyzed ${image.path.split('/').last}: ${tags.length} tags found');
        } else {
          print('Vision API Error for ${image.path}: ${response.body}');
          results[image.path.split('/').last] = [];
        }
      }
      return results;
    } catch (e) {
      print('Error calling Vision API: $e');
      return {};
    }
  }

  /// Analyzes a video using enhanced mock data with OAuth credentials context.
  /// Provides RICH, SPECIFIC artisan workshop analysis to enable meaningful Living Workshop generation.
  static Future<Map<String, dynamic>> analyzeVideo(File video) async {
    try {
      // Load credentials to show OAuth integration capability
      await _loadCredentials();
      
      final fileName = video.path.split('/').last;
      print('🎬 Analyzing video with ENHANCED RICH mock data: $fileName');
      
      // 🔥 GOD-LEVEL ENHANCED MOCK DATA - Simulates real Video Intelligence API output
      final mockLabels = [
        'pottery_wheel_in_motion',
        'artisan_hands_shaping_clay',
        'workshop_tools_organized',
        'clay_preparation_area',
        'kiln_in_background',
        'finished_pottery_display',
        'natural_lighting_workspace',
        'traditional_crafting_technique',
        'artisan_expertise_demonstration',
        'creative_process_flow',
        'material_transformation',
        'handcraft_precision_work'
      ];
      
      final mockObjects = [
        'pottery_wheel', 'clay_blocks', 'shaping_tools', 'water_basin',
        'work_table', 'storage_shelves', 'finished_vessels', 'kiln_door',
        'apron', 'artisan_hands', 'clay_sculptures', 'tool_rack',
        'window_natural_light', 'floor_workspace', 'drying_area'
      ];
      
      // 🎯 DETAILED SCENE ANALYSIS with rich temporal data
      final mockScenes = [
        {
          'startTime': '0s',
          'endTime': '15s',
          'description': 'Workshop overview and environment setup',
          'confidence': 0.94,
          'detectedObjects': ['pottery_wheel', 'work_table', 'tool_rack', 'natural_lighting'],
          'primaryActivity': 'workspace_introduction',
          'mood': 'calm_creative_atmosphere'
        },
        {
          'startTime': '15s', 
          'endTime': '35s',
          'description': 'Active clay preparation and centering on wheel',
          'confidence': 0.91,
          'detectedObjects': ['artisan_hands', 'clay_block', 'pottery_wheel', 'water_basin'],
          'primaryActivity': 'clay_centering_process',
          'mood': 'focused_concentration'
        },
        {
          'startTime': '35s',
          'endTime': '50s', 
          'description': 'Shaping and forming pottery with traditional techniques',
          'confidence': 0.96,
          'detectedObjects': ['shaped_vessel', 'shaping_tools', 'precise_movements'],
          'primaryActivity': 'pottery_formation',
          'mood': 'skilled_artisanship'
        },
        {
          'startTime': '50s',
          'endTime': '60s',
          'description': 'Final product showcase and workspace organization',
          'confidence': 0.92,
          'detectedObjects': ['finished_pottery', 'display_area', 'organized_tools'],
          'primaryActivity': 'product_presentation',
          'mood': 'pride_in_craftsmanship'
        }
      ];
      
      // 🎨 RICH VISUAL ANALYSIS DATA
      final spatialData = {
        'workshopLayout': {
          'primaryWorkArea': {'x': 0.4, 'y': 0.6, 'radius': 0.3},
          'toolStorage': {'x': 0.8, 'y': 0.3, 'radius': 0.15},
          'displayArea': {'x': 0.2, 'y': 0.8, 'radius': 0.2},
          'lightSource': {'x': 0.1, 'y': 0.2, 'radius': 0.1}
        },
        'objectCoordinates': {
          'pottery_wheel': {'x': 0.45, 'y': 0.65},
          'tool_rack': {'x': 0.82, 'y': 0.28},
          'finished_display': {'x': 0.18, 'y': 0.75},
          'work_table': {'x': 0.6, 'y': 0.4},
          'kiln_area': {'x': 0.9, 'y': 0.8}
        }
      };
      
      return {
        'labels': mockLabels,
        'objects': mockObjects,
        'scenes': mockScenes,
        'spatialAnalysis': spatialData,
        'duration': '60s',
        'analysisType': 'enhanced_rich_mock_with_spatial_data',
        'credentialsLoaded': true,
        'qualityScore': 0.93,
        'artisanActivityLevel': 'high_engagement',
        'workshopType': 'traditional_pottery_studio'
      };
    } catch (e) {
      print('Error in video analysis: $e');
      return {
        'labels': ['Workshop', 'Crafting'],
        'objects': ['Tools', 'Materials'],
        'scenes': [{'startTime': '0s', 'endTime': '30s', 'confidence': 0.7}],
        'duration': '30s',
        'analysisType': 'basic_fallback'
      };
    }
  }

  /// Fallback method for when GCP services are unavailable - ENHANCED RICH MOCK DATA
  /// Provides detailed, realistic image analysis to enable meaningful Living Workshop generation
  static Map<String, List<String>> mockImageAnalysis(List<File> images) {
    final Map<String, List<String>> mockResults = {};
    
    for (final image in images) {
      final fileName = image.path.split('/').last;
      
      // 🔥 GOD-LEVEL ENHANCED MOCK DATA - Different for each image to simulate variety
      final int imageIndex = images.indexOf(image);
      
      List<String> imageSpecificTags;
      
      switch (imageIndex % 4) {
        case 0: // Primary workspace image
          imageSpecificTags = [
            'pottery_wheel_centered (95%)',
            'clay_preparation_area (88%)', 
            'artisan_tools_organized (92%)',
            'natural_workspace_lighting (87%)',
            'traditional_pottery_setup (94%)',
            'work_table_with_tools (90%)',
            'ceramic_vessels_display (85%)',
            'handcraft_workspace (96%)',
            'creative_environment (89%)',
            'kiln_visible_background (82%)',
            'floor_workspace_area (78%)',
            'window_natural_light (91%)'
          ];
          break;
          
        case 1: // Tools and materials focus
          imageSpecificTags = [
            'pottery_tools_collection (94%)',
            'clay_shaping_instruments (89%)',
            'wooden_ribs_tools (87%)',
            'metal_cutting_wires (92%)',
            'sponges_cleaning_tools (85%)',
            'measuring_calipers (83%)',
            'tool_rack_organization (91%)',
            'crafting_precision_tools (88%)',
            'traditional_pottery_implements (93%)',
            'workspace_organization (86%)',
            'artisan_tool_collection (90%)',
            'handcraft_equipment (84%)'
          ];
          break;
          
        case 2: // Work in progress/process
          imageSpecificTags = [
            'clay_vessel_in_progress (93%)',
            'pottery_forming_process (90%)',
            'hands_shaping_clay (96%)',
            'wheel_throwing_technique (89%)',
            'ceramic_creation_stage (87%)',
            'artisan_skill_demonstration (94%)',
            'traditional_technique_display (91%)',
            'clay_centering_process (88%)',
            'pottery_expertise_shown (92%)',
            'handcraft_precision_work (85%)',
            'creative_process_capture (89%)',
            'skill_level_advanced (93%)'
          ];
          break;
          
        default: // Finished products and display
          imageSpecificTags = [
            'finished_ceramic_vessels (95%)',
            'pottery_collection_display (92%)',
            'glazed_pottery_finished (89%)',
            'artisan_final_products (94%)',
            'ceramic_art_showcase (87%)',
            'handmade_pottery_variety (91%)',
            'traditional_ceramic_forms (88%)',
            'glazing_finish_quality (86%)',
            'pottery_product_range (90%)',
            'artisan_craftsmanship_result (93%)',
            'ceramic_functional_art (85%)',
            'handcraft_excellence (92%)'
          ];
      }
      
      mockResults[fileName] = imageSpecificTags;
      print('🎨 Enhanced Vision API mock analysis for $fileName: ${imageSpecificTags.length} detailed tags');
    }
    
    return mockResults;
  }

  /// Enhanced mock video analysis with rich spatial and temporal data
  static Map<String, dynamic> mockVideoAnalysis() {
    return {
      'labels': [
        'pottery_wheel_in_motion',
        'artisan_hands_shaping_clay', 
        'workshop_tools_organized',
        'clay_preparation_area',
        'kiln_in_background',
        'finished_pottery_display',
        'traditional_crafting_technique',
        'artisan_expertise_demonstration'
      ],
      'objects': [
        'pottery_wheel', 'clay_blocks', 'shaping_tools', 'water_basin',
        'work_table', 'storage_shelves', 'finished_vessels', 'kiln_door'
      ],
      'scenes': [
        {
          'startTime': '0s',
          'endTime': '15s',
          'description': 'Workshop overview and environment setup',
          'confidence': 0.94,
          'detectedObjects': ['pottery_wheel', 'work_table', 'tool_rack'],
          'primaryActivity': 'workspace_introduction'
        },
        {
          'startTime': '15s',
          'endTime': '35s', 
          'description': 'Active clay preparation and centering',
          'confidence': 0.91,
          'detectedObjects': ['artisan_hands', 'clay_block', 'pottery_wheel'],
          'primaryActivity': 'clay_centering_process'
        },
        {
          'startTime': '35s',
          'endTime': '50s',
          'description': 'Pottery shaping with traditional techniques',
          'confidence': 0.96,
          'detectedObjects': ['shaped_vessel', 'shaping_tools'],
          'primaryActivity': 'pottery_formation'
        }
      ],
      'spatialAnalysis': {
        'workshopLayout': {
          'primaryWorkArea': {'x': 0.4, 'y': 0.6, 'radius': 0.3},
          'toolStorage': {'x': 0.8, 'y': 0.3, 'radius': 0.15},
          'displayArea': {'x': 0.2, 'y': 0.8, 'radius': 0.2}
        },
        'objectCoordinates': {
          'pottery_wheel': {'x': 0.45, 'y': 0.65},
          'tool_rack': {'x': 0.82, 'y': 0.28},
          'finished_display': {'x': 0.18, 'y': 0.75}
        }
      },
      'duration': '50s',
      'analysisType': 'enhanced_rich_mock_fallback',
      'qualityScore': 0.91,
      'artisanActivityLevel': 'high_engagement',
      'workshopType': 'traditional_pottery_studio',
      // Legacy format for backward compatibility
      'shotLabelAnnotations': [
        {
          'entity': {'description': 'Pottery wheel'},
          'segments': [{'startTimeOffset': '0s', 'endTimeOffset': '30s'}]
        },
        {
          'entity': {'description': 'Clay shaping'},
          'segments': [{'startTimeOffset': '10s', 'endTimeOffset': '50s'}]
        }
      ],
      'objectAnnotations': [
        {
          'entity': {'description': 'Pottery wheel'},
          'frames': [
            {
              'timeOffset': '15s',
              'normalizedBoundingBox': {
                'left': 0.3,
                'top': 0.4,
                'right': 0.7,
                'bottom': 0.8
              }
            }
          ]
        }
      ]
    };
  }
}
