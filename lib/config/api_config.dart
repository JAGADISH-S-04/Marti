/// API Configuration for Google Cloud Services
/// Centralized management of API keys and endpoints
class ApiConfig {
  // Google Cloud API Key
  static const String googleCloudApiKey = 'AIzaSyDTSK7J0Bcd44pekwFitMxfMNGGkSSDO80';
  
  // Google Cloud Service Endpoints
  static const String vertexAiEndpoint = 'https://us-central1-aiplatform.googleapis.com/v1/projects';
  static const String translateApiEndpoint = 'https://translation.googleapis.com/language/translate/v2';
  static const String visionApiEndpoint = 'https://vision.googleapis.com/v1/images:annotate';
  static const String geminiApiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  static const String trendsApiEndpoint = 'https://trends.googleapis.com/v1beta';
  
  // Project Configuration
  static const String projectId = 'arti-marketplace'; // Update with your actual project ID
  static const String location = 'us-central1';
  
  // API Key Getter Methods for different services
  static String get geminiApiKey => googleCloudApiKey;
  static String get visionApiKey => googleCloudApiKey;
  static String get translateApiKey => googleCloudApiKey;
  static String get vertexAiApiKey => googleCloudApiKey;
  
  // Helper method to construct full Vertex AI endpoint
  static String getVertexAiEndpoint({
    required String projectId,
    required String model,
    String location = 'us-central1',
  }) {
    return '$vertexAiEndpoint/$projectId/locations/$location/publishers/google/models/$model:predict';
  }
  
  // Helper method to construct Vision API URL with key
  static String get visionApiUrlWithKey => '$visionApiEndpoint?key=$visionApiKey';
  
  // Helper method to construct Translate API URL with key
  static String get translateApiUrlWithKey => '$translateApiEndpoint?key=$translateApiKey';
  
  // Security note: In production, consider:
  // 1. Using Firebase Remote Config for dynamic API key management
  // 2. Implementing API key rotation
  // 3. Using Firebase Functions for server-side API calls
  // 4. Implementing request rate limiting
  // 5. Adding API usage monitoring
}
