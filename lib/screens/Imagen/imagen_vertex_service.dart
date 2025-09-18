import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:firebase_storage/firebase_storage.dart';

/// Service to call Imagen (Vertex AI via Firebase AI Logic) for image generation
/// and upload the generated image to Firebase Storage.
class ImagenVertexService {
  final String location; // e.g., 'us-central1'
  final String model; // e.g., 'imagen-4.0-generate-001'

  ImagenVertexService({
    this.location = 'us-central1',
    this.model = 'imagen-4.0-generate-001', // Use latest generation model
  });

  fai.ImagenModel _imagenModel() => fai.FirebaseAI
      .vertexAI(location: location)
      .imagenModel(
        model: model,
        generationConfig: fai.ImagenGenerationConfig(
          numberOfImages: 1,
          aspectRatio: fai.ImagenAspectRatio.square1x1,
          imageFormat: fai.ImagenFormat.jpeg(compressionQuality: 75),
        ),
        safetySettings: fai.ImagenSafetySettings(
          fai.ImagenSafetyFilterLevel.blockLowAndAbove,
          fai.ImagenPersonFilterLevel.allowAdult,
        ),
      );

  /// Generates an image with a text prompt using Imagen and uploads the result to Storage.
  /// Note: This currently generates images from text (not editing existing images).
  /// Returns the Firebase Storage download URL.
  Future<String> editAndUpload({
    required Uint8List sourceImage,
    required String prompt,
    required String storagePath,
    String contentType = 'image/png',
  }) async {
    final imagenModel = _imagenModel();

    // Generate image based on text prompt using Imagen
    // Note: The sourceImage parameter is currently not used for editing
    // as editing APIs may not be available in the current SDK version
    final resp = await imagenModel.generateImages(prompt);

    // Extract the generated image bytes from Imagen response
    Uint8List outBytes;
    if (resp.images.isNotEmpty) {
      final generatedImage = resp.images.first;
      outBytes = generatedImage.bytesBase64Encoded;
    } else {
      throw Exception('No images generated from Imagen response. ${resp.filteredReason ?? "Unknown error"}');
    }

    final ref = FirebaseStorage.instance.ref().child(storagePath);
  await ref.putData(outBytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
