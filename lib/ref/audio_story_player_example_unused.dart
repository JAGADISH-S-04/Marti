import 'package:arti/widgets/audio_story_player.dart';
import 'package:flutter/material.dart';

/// Example of how to use the enhanced AudioStoryPlayer with edit functionality
class AudioStoryPlayerExample extends StatefulWidget {
  const AudioStoryPlayerExample({Key? key}) : super(key: key);

  @override
  State<AudioStoryPlayerExample> createState() => _AudioStoryPlayerExampleState();
}

class _AudioStoryPlayerExampleState extends State<AudioStoryPlayerExample> {
  String currentTranscription = 'நாதமதன் அவ்வளவுதான்.'; // Initial Tamil text
  
  final Map<String, String> availableTranslations = {
    'hindi': 'यह मेरी कहानी है।',
    'english': 'This is my story.',
    'bengali': 'এটি আমার গল্প।',
    'telugu': 'ఇది నా కథ.',
  };

  void _onTextChanged(String newText) {
    setState(() {
      currentTranscription = newText;
    });
    
    // Here you would typically save to Firebase or your backend
    print('Text updated: $newText');
    
    // Show confirmation to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Story updated successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onTranslationChanged(String languageCode, String translatedText) {
    setState(() {
      availableTranslations[languageCode] = translatedText;
    });
    
    // Here you would typically save to Firebase or your backend
    print('Translation updated for $languageCode: $translatedText');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Story Player Demo'),
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Example 1: Read-only mode (for buyers)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Read-Only Mode (Buyer View)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AudioStoryPlayer(
                      audioUrl: 'https://example.com/audio.mp3',
                      transcription: currentTranscription,
                      translations: availableTranslations,
                      artisanName: 'Ravi Kumar',
                      enableEditing: false, // Read-only
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Example 2: Editable mode (for sellers/artisans)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Editable Mode (Seller View)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click the edit icon to modify the story text',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AudioStoryPlayer(
                      audioUrl: 'https://example.com/audio.mp3',
                      transcription: currentTranscription,
                      translations: availableTranslations,
                      artisanName: 'Ravi Kumar',
                      enableEditing: true, // Editable
                      onTextChanged: _onTextChanged,
                      onTranslationChanged: _onTranslationChanged,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Current state display
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current State:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Original Text: $currentTranscription',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available Translations: ${availableTranslations.length}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    ...availableTranslations.entries.map((entry) => 
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example usage instructions
/// 
/// To use the enhanced AudioStoryPlayer:
/// 
/// 1. For READ-ONLY mode (buyers):
/// ```dart
/// AudioStoryPlayer(
///   audioUrl: 'your_audio_url',
///   transcription: 'your_text',
///   translations: yourTranslations,
///   artisanName: 'Artisan Name',
///   enableEditing: false, // Important: set to false
/// )
/// ```
/// 
/// 2. For EDITABLE mode (sellers/artisans):
/// ```dart
/// AudioStoryPlayer(
///   audioUrl: 'your_audio_url',
///   transcription: 'your_text',
///   translations: yourTranslations,
///   artisanName: 'Artisan Name',
///   enableEditing: true, // Important: set to true
///   onTextChanged: (newText) {
///     // Handle text changes
///     // Update your database/Firebase here
///   },
///   onTranslationChanged: (langCode, translatedText) {
///     // Handle translation changes
///     // Update your database/Firebase here
///   },
/// )
/// ```
/// 
/// Features:
/// - Edit button appears only when enableEditing is true and viewing original language
/// - Text becomes editable in a TextField when edit mode is activated
/// - Save/Cancel buttons for confirming or discarding changes
/// - Callbacks for handling text and translation updates
/// - Maintains all existing audio playback functionality
/// - Language switching still works as before
