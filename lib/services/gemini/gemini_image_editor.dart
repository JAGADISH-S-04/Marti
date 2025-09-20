import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'gemini_image_service.dart';

/// Specialized image editing operations using Gemini 2.5 Flash Image Preview
/// 
/// This class provides high-level, user-friendly methods for common image editing tasks
/// that were impossible with Firebase AI SDK v2.2.0 limitations.
/// 
/// Key Features:
/// - ACTUAL source image editing (not just text-to-image generation)
/// - Professional photo editing capabilities
/// - E-commerce product enhancement
/// - Artistic style transformations
/// - Social media content creation
class GeminiImageEditor {
  final GeminiImageService _geminiService;
  
  GeminiImageEditor(this._geminiService);
  
  /// Professional Photo Enhancement Suite
  
  /// Remove objects or people from photos seamlessly
  Future<ImageGenerationResult> removeObject({
    required Uint8List sourceImage,
    required String objectDescription,
    String? replacementDescription,
  }) async {
    debugPrint('🗑️ Removing object: $objectDescription');
    
    String prompt = 'Remove the $objectDescription from this image completely. ';
    
    if (replacementDescription != null) {
      prompt += 'Replace the removed area with $replacementDescription, ';
    } else {
      prompt += 'Fill the removed area naturally with appropriate background content, ';
    }
    
    prompt += '''ensuring:
- No traces of the original object remain
- The background flows seamlessly
- Natural lighting and shadows are maintained
- The composition remains balanced and visually appealing''';
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.remove,
    );
  }
  
  /// Add objects or elements to existing photos
  Future<ImageGenerationResult> addObject({
    required Uint8List sourceImage,
    required String objectDescription,
    required String positionDescription,
    String styleInstructions = 'seamlessly integrated',
  }) async {
    debugPrint('➕ Adding object: $objectDescription');
    
    final prompt = '''Add $objectDescription to this image at $positionDescription. 
    
The added element should be:
- $styleInstructions
- Properly lit to match the existing lighting
- Correctly sized and positioned for realistic perspective
- Naturally integrated with appropriate shadows and reflections
- Consistent with the image's overall style and mood''';
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.add,
    );
  }
  
  /// Change background while keeping subject intact
  Future<ImageGenerationResult> changeBackground({
    required Uint8List sourceImage,
    required String newBackgroundDescription,
    String? subjectDescription,
  }) async {
    debugPrint('🌅 Changing background to: $newBackgroundDescription');
    
    String prompt = 'Replace the background of this image with $newBackgroundDescription. ';
    
    if (subjectDescription != null) {
      prompt += 'Keep the $subjectDescription in the foreground exactly as they are, ';
    } else {
      prompt += 'Keep all foreground subjects exactly as they are, ';
    }
    
    prompt += '''ensuring:
- The subject edges are clean and natural
- Lighting on the subject matches the new background
- Appropriate shadows are cast on the new background
- The perspective and depth of field are consistent
- The overall composition remains professional''';
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
  
  /// E-commerce Product Enhancement
  
  /// Enhance product photos for e-commerce
  Future<ImageGenerationResult> enhanceProductPhoto({
    required Uint8List productImage,
    ProductPhotoStyle style = ProductPhotoStyle.clean,
    String? customBackground,
  }) async {
    debugPrint('🛍️ Enhancing product photo with ${style.name} style');
    
    String backgroundInstruction = '';
    switch (style) {
      case ProductPhotoStyle.clean:
        backgroundInstruction = 'clean white background with soft, even lighting';
        break;
      case ProductPhotoStyle.lifestyle:
        backgroundInstruction = customBackground ?? 'modern lifestyle setting that complements the product';
        break;
      case ProductPhotoStyle.luxury:
        backgroundInstruction = 'premium, luxurious setting with elegant lighting';
        break;
      case ProductPhotoStyle.minimal:
        backgroundInstruction = 'minimalist background with negative space and subtle shadows';
        break;
    }
    
    final prompt = '''Transform this product image into a professional e-commerce photo with:
- $backgroundInstruction
- Studio-quality lighting that eliminates harsh shadows
- Enhanced product details and textures
- Crisp, sharp focus on the product
- Professional color correction and white balance
- Optimal composition for online sales
- High-resolution, retail-ready quality''';
    
    return await _geminiService.editImage(
      sourceImageBytes: productImage,
      editPrompt: prompt,
      mode: EditingMode.enhance,
    );
  }
  
  /// Create product mockups in different contexts
  Future<ImageGenerationResult> createProductMockup({
    required Uint8List productImage,
    required String contextDescription,
    String? personDescription,
  }) async {
    debugPrint('📸 Creating product mockup in: $contextDescription');
    
    String prompt = 'Create a realistic product mockup by placing this product in $contextDescription. ';
    
    if (personDescription != null) {
      prompt += 'Include $personDescription using or wearing the product naturally. ';
    }
    
    prompt += '''Ensure the mockup shows:
- Realistic product placement and sizing
- Natural interaction with the environment
- Proper lighting and shadows
- Believable perspective and depth
- Professional photography quality
- Authentic, non-promotional appearance''';
    
    return await _geminiService.editImage(
      sourceImageBytes: productImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
  
  /// Artistic Transformations
  
  /// Apply artistic filters and effects
  Future<ImageGenerationResult> applyArtisticStyle({
    required Uint8List sourceImage,
    required ArtisticStyle style,
    String? customStyleDescription,
  }) async {
    debugPrint('🎨 Applying artistic style: ${style.name}');
    
    String styleDescription = '';
    switch (style) {
      case ArtisticStyle.oilPainting:
        styleDescription = 'oil painting with visible brush strokes and rich textures';
        break;
      case ArtisticStyle.watercolor:
        styleDescription = 'watercolor painting with soft, flowing colors and transparent washes';
        break;
      case ArtisticStyle.sketch:
        styleDescription = 'pencil sketch with detailed line work and shading';
        break;
      case ArtisticStyle.cartoonish:
        styleDescription = 'cartoon style with bold colors and simplified features';
        break;
      case ArtisticStyle.vintage:
        styleDescription = 'vintage photography style with aged colors and retro atmosphere';
        break;
      case ArtisticStyle.modern:
        styleDescription = 'modern digital art style with clean lines and contemporary aesthetics';
        break;
      case ArtisticStyle.custom:
        styleDescription = customStyleDescription ?? 'artistic interpretation';
        break;
    }
    
    final prompt = '''Transform this image into a $styleDescription while:
- Preserving the original composition and subject matter
- Maintaining recognizable features and details
- Applying consistent artistic treatment throughout
- Creating a cohesive artistic vision
- Ensuring high artistic quality and professional finish''';
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
  
  /// Create artistic double exposure effects
  Future<ImageGenerationResult> createDoubleExposure({
    required Uint8List portraitImage,
    required Uint8List overlayImage,
    String blendMode = 'dreamy and ethereal',
  }) async {
    debugPrint('👥 Creating double exposure effect');
    
    final prompt = '''Create a stunning double exposure effect by artistically blending these two images:
- Use the first image as the primary subject (portrait base)
- Overlay the second image as the texture/pattern layer
- Blend them in a $blendMode style
- Ensure the subject's silhouette remains clearly defined
- Create smooth transitions between the images
- Maintain artistic balance and visual harmony
- Result should be a single, cohesive artistic piece''';
    
    return await _geminiService.composeFromMultipleImages(
      sourceImages: [portraitImage, overlayImage],
      compositionPrompt: prompt,
    );
  }
  
  /// Social Media Content Creation
  
  /// Create Instagram-ready content with perfect dimensions
  Future<ImageGenerationResult> createInstagramPost({
    required Uint8List sourceImage,
    String? overlayText,
    InstagramStyle style = InstagramStyle.modern,
  }) async {
    debugPrint('📱 Creating Instagram post with ${style.name} style');
    
    String styleInstructions = '';
    switch (style) {
      case InstagramStyle.modern:
        styleInstructions = 'modern, clean aesthetic with contemporary design elements';
        break;
      case InstagramStyle.vintage:
        styleInstructions = 'vintage filter with warm tones and retro atmosphere';
        break;
      case InstagramStyle.minimal:
        styleInstructions = 'minimalist design with lots of white space and simple typography';
        break;
      case InstagramStyle.vibrant:
        styleInstructions = 'vibrant, eye-catching colors with high contrast and saturation';
        break;
    }
    
    String prompt = '''Transform this image into an Instagram-ready post with:
- Perfect 1:1 square aspect ratio
- $styleInstructions
- Enhanced colors and contrast for mobile viewing
- Professional composition optimized for social media''';
    
    if (overlayText != null) {
      prompt += '''
- Add the text "$overlayText" in a stylish, readable font
- Position text for maximum impact without obscuring key image elements
- Use appropriate text styling that matches the overall aesthetic''';
    }
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
  
  /// Create story-format content for social media
  Future<ImageGenerationResult> createStoryContent({
    required Uint8List sourceImage,
    String? storyText,
    String callToAction = '',
  }) async {
    debugPrint('📚 Creating story content');
    
    String prompt = '''Transform this image into engaging social media story content with:
- Vertical 9:16 aspect ratio perfect for stories
- Eye-catching visual composition
- Mobile-optimized design and readability
- Engaging visual hierarchy''';
    
    if (storyText != null) {
      prompt += '''
- Add the text "$storyText" in an engaging, story-appropriate style
- Use modern, mobile-friendly typography
- Position text for maximum readability and impact''';
    }
    
    if (callToAction.isNotEmpty) {
      prompt += '''
- Include a subtle call-to-action: "$callToAction"
- Design it to encourage user engagement
- Make it visually appealing but not overwhelming''';
    }
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
  
  /// Advanced Editing Techniques
  
  /// Selective color editing - change specific colors while keeping others
  Future<ImageGenerationResult> changeSelectiveColors({
    required Uint8List sourceImage,
    required String targetColor,
    required String newColor,
    String? affectedObjects,
  }) async {
    debugPrint('🎨 Changing $targetColor to $newColor');
    
    String prompt = 'Change all $targetColor colors in this image to $newColor. ';
    
    if (affectedObjects != null) {
      prompt += 'Focus specifically on the $targetColor elements in the $affectedObjects. ';
    }
    
    prompt += '''Ensure:
- Only the specified colors are modified
- All other colors remain exactly the same
- Natural color transitions and gradients are preserved
- Lighting and shadows are adjusted appropriately
- The overall image composition remains unchanged''';
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.inpaint,
    );
  }
  
  /// Age progression or regression effects
  Future<ImageGenerationResult> ageTransformation({
    required Uint8List portraitImage,
    required int targetAge,
    bool preserveIdentity = true,
  }) async {
    debugPrint('👤 Age transformation to $targetAge years');
    
    String identityInstruction = preserveIdentity
        ? 'while maintaining the person\'s core facial features and identity'
        : 'with natural aging progression';
    
    final prompt = '''Transform this portrait to show the person at approximately $targetAge years old $identityInstruction.
    
Apply realistic aging effects:
- Natural skin texture changes appropriate for the target age
- Realistic hair color and style changes
- Appropriate facial structure modifications
- Natural wrinkle patterns and skin variations
- Maintain the person's essential character and expression
- Ensure photorealistic results
- Keep lighting and photo quality consistent''';
    
    return await _geminiService.editImage(
      sourceImageBytes: portraitImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
  
  /// Weather and atmospheric effects
  Future<ImageGenerationResult> addWeatherEffect({
    required Uint8List sourceImage,
    required WeatherEffect weather,
    double intensity = 0.7,
  }) async {
    debugPrint('🌦️ Adding weather effect: ${weather.name}');
    
    String weatherDescription = '';
    switch (weather) {
      case WeatherEffect.rain:
        weatherDescription = 'realistic rain with water droplets and wet surfaces';
        break;
      case WeatherEffect.snow:
        weatherDescription = 'falling snow with accumulation on surfaces';
        break;
      case WeatherEffect.fog:
        weatherDescription = 'atmospheric fog with reduced visibility';
        break;
      case WeatherEffect.sunset:
        weatherDescription = 'warm sunset lighting with golden hour atmosphere';
        break;
      case WeatherEffect.storm:
        weatherDescription = 'dramatic storm clouds with moody lighting';
        break;
      case WeatherEffect.rainbow:
        weatherDescription = 'beautiful rainbow with appropriate atmospheric conditions';
        break;
    }
    
    final intensityDescription = intensity > 0.8 ? 'strong' : intensity > 0.5 ? 'moderate' : 'subtle';
    
    final prompt = '''Add $intensityDescription $weatherDescription to this image while:
- Maintaining the original scene composition
- Ensuring realistic weather physics and lighting
- Creating appropriate atmospheric perspective
- Adding natural environmental effects (reflections, shadows, etc.)
- Preserving image quality and detail
- Making the weather effect look completely natural and believable''';
    
    return await _geminiService.editImage(
      sourceImageBytes: sourceImage,
      editPrompt: prompt,
      mode: EditingMode.modify,
    );
  }
}

/// Product photo enhancement styles
enum ProductPhotoStyle {
  clean,      // Clean white background
  lifestyle,  // Lifestyle context
  luxury,     // Premium/luxury setting
  minimal,    // Minimalist design
}

/// Artistic transformation styles
enum ArtisticStyle {
  oilPainting,
  watercolor,
  sketch,
  cartoonish,
  vintage,
  modern,
  custom,
}

/// Instagram content styles
enum InstagramStyle {
  modern,
  vintage,
  minimal,
  vibrant,
}

/// Weather effect types
enum WeatherEffect {
  rain,
  snow,
  fog,
  sunset,
  storm,
  rainbow,
}