# Living Workshop Feature - Implementation Guide

## Overview

The **Living Workshop** is a groundbreaking feature that transforms an artisan's raw media (workshop videos, photos, and audio stories) into an interactive, explorable digital experience using AI-powered analysis and creative generation.

## How It Works

### 1. **Media Collection**
Artisans upload:
- 📹 A 1-3 minute workshop video tour
- 📸 Multiple photos of their workspace, tools, and materials
- 🎙️ An audio story about their craft

### 2. **AI-Powered Analysis Pipeline**
- **Google Cloud Vision API**: Analyzes photos to identify objects, tools, and workspace elements
- **Google Cloud Video Intelligence API**: Analyzes video to detect scenes, objects, and timestamps
- **Gemini API**: Transcribes audio and acts as the central "brain" to synthesize all data

### 3. **Interactive Experience Generation**
The AI creates:
- Poetic descriptions of workshop elements
- Interactive hotspots positioned on the workspace image
- Contextual product mappings to relevant artisan products
- An immersive, shoppable experience

## Setup Instructions

### Prerequisites
1. **Google Cloud Platform Account**
2. **Firebase Project** (already configured)
3. **Gemini API Key** (already configured)

### GCP Setup

#### 1. Enable Required APIs
In your Google Cloud Console, enable:
- Cloud Vision API
- Cloud Video Intelligence API

#### 2. Create Service Account
1. Go to **IAM & Admin > Service Accounts**
2. Click **"Create Service Account"**
3. Name: `arti-living-workshop`
4. Grant roles:
   - Cloud Vision AI Service User
   - Cloud Video Intelligence Service User

#### 3. Generate Service Account Key
1. Click on your service account
2. Go to **"Keys"** tab
3. Click **"Add Key" > "Create new key"**
4. Choose **JSON** format
5. Download the JSON file

#### 4. Update Configuration
1. Replace the contents of `assets/gcp-service-key.json` with your downloaded JSON
2. Update the project ID in `lib/services/gcp_service.dart`:
   ```dart
   static const String _gcpProjectId = 'your-actual-project-id';
   ```

## File Structure

```
lib/
├── screens/
│   ├── artisan_media_upload_screen.dart    # Media upload interface
│   └── living_workshop_screen.dart         # Interactive workshop viewer
├── services/
│   ├── gcp_service.dart                   # Google Cloud APIs integration
│   ├── living_workshop_service.dart       # Workshop data management
│   └── gemini_service.dart               # Enhanced with workshop generation
└── widgets/
    └── artisan_legacy_story_widget.dart   # Updated with workshop button
```

## Usage Flow

### For Artisans (Sellers):
1. Go to **Seller Dashboard**
2. Click **"Living Workshop"** button
3. Upload workshop video (1-3 minutes)
4. Upload workspace photos (multiple images)
5. Record audio story (60-90 seconds)
6. Click **"Generate My Living Workshop"**
7. Wait for AI processing (2-5 minutes)
8. Preview the interactive experience

### For Buyers:
1. View any product with an artisan legacy story
2. Click **"Explore the Living Workshop"** button
3. Interact with glowing hotspots on the workshop image
4. Listen to ambient audio story
5. Browse products contextually mapped to workspace elements
6. Purchase directly from the interactive experience

## Technical Features

### AI-Powered Object Detection
- Identifies pottery wheels, looms, chisels, kilns, workbenches
- Recognizes materials like clay, wood, fabric, metal
- Detects finished products and work-in-progress items

### Intelligent Product Mapping
- Maps pottery wheels to ceramic products
- Connects woodworking tools to carved items
- Links textile equipment to fabric products
- Suggests relevant items based on visual context

### Immersive Experience Elements
- **Animated Hotspots**: Pulsing interactive points
- **Ambient Audio**: Artisan's story plays in background
- **Contextual Product Cards**: Slide-up product displays
- **Poetic Descriptions**: AI-generated evocative text

## Error Handling & Fallbacks

### GCP API Failures
If Google Cloud APIs are unavailable, the system:
- Uses mock data for demonstration
- Still generates a functional workshop experience
- Logs warnings for debugging

### Graceful Degradation
- Missing audio: Visual-only experience
- No video: Photo-based workshop
- Limited photos: Single-image interactive space

## Performance Considerations

### Media Upload Optimization
- Video size limit: 50MB
- Photo compression: Automatic
- Progress indicators: Real-time upload status

### Processing Time
- Image analysis: 10-30 seconds
- Video analysis: 1-3 minutes
- AI generation: 30-60 seconds
- Total time: 2-5 minutes

### Caching Strategy
- Workshop data cached in Firestore
- Media files stored in Firebase Storage
- Regeneration only when explicitly requested

## Security & Privacy

### Data Protection
- Service account keys secured
- Media files private by default
- Workshop data accessible only to artisan and viewers

### Access Control
- Artisans can delete their workshops
- Workshop visibility controlled by artisan
- Buyer access requires valid product context

## Troubleshooting

### Common Issues

**1. GCP Authentication Error**
```
Error getting authenticated client
```
**Solution**: Verify service account JSON is correctly placed and formatted

**2. Video Analysis Timeout**
```
Video analysis timed out after 200 seconds
```
**Solution**: Try with shorter video or check GCP quota limits

**3. No Products Found**
```
No products found for this artisan
```
**Solution**: Artisan must create products before generating workshop

### Debug Mode
Enable detailed logging by setting:
```dart
// In gcp_service.dart
static const bool debugMode = true;
```

## Future Enhancements

### Planned Features
- **VR/AR Integration**: Mobile VR workshop tours
- **Live Workshops**: Real-time streaming with interactive elements
- **Collaborative Spaces**: Multiple artisans in shared workshops
- **Customer Workshops**: Buyers create their own craft spaces

### API Expansions
- **Natural Language API**: Enhanced text analysis
- **AutoML**: Custom object detection models
- **Translation API**: Multi-language workshop experiences

## Cost Considerations

### GCP API Costs
- **Vision API**: ~$1.50 per 1,000 images
- **Video Intelligence**: ~$0.10 per minute
- **Typical Workshop**: $0.02-0.05 per generation

### Optimization Tips
- Batch process multiple artisans
- Use regional storage for media
- Implement smart caching strategies
- Monitor API usage quotas

## Support

For technical support or feature requests:
1. Check the troubleshooting section
2. Review GCP console for API errors
3. Enable debug logging for detailed analysis
4. Contact development team with error logs

---

*The Living Workshop feature represents a fusion of traditional craftsmanship with cutting-edge AI technology, creating unprecedented connections between artisans and their customers.*
