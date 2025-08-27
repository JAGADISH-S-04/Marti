import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/store_audio_recorder.dart';
import '../widgets/seller_store_audio_editor.dart';
import '../services/store_service.dart';

class StoreAudioManagementPage extends StatefulWidget {
  const StoreAudioManagementPage({Key? key}) : super(key: key);

  @override
  State<StoreAudioManagementPage> createState() => _StoreAudioManagementPageState();
}

class _StoreAudioManagementPageState extends State<StoreAudioManagementPage> {
  final StoreService _storeService = StoreService();
  
  bool _isLoading = true;
  DocumentSnapshot? _storeDoc;
  Map<String, dynamic>? _storeData;
  String? _errorMessage;

  // Colors matching the luxury theme
  static const Color primaryBrown = Color(0xFF2C1810);
  static const Color accentGold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please sign in to access this page';
        _isLoading = false;
      });
      return;
    }

    try {
      _storeDoc = await _storeService.getStoreByUserId(user.uid);
      
      if (_storeDoc != null) {
        _storeData = _storeDoc!.data() as Map<String, dynamic>;
      } else {
        _errorMessage = 'No store found. Please create a store first.';
      }
    } catch (e) {
      _errorMessage = 'Error loading store data: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStoreData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadStoreData();
  }

  void _onAudioStoryComplete(String audioUrl, String transcription, Map<String, String> translations) {
    // Refresh the store data to show the new audio story
    _refreshStoreData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Store audio story uploaded successfully! Customers can now hear your story.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _deleteAudioStory() async {
    if (_storeDoc == null || _storeData == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Delete Audio Story',
                style: GoogleFonts.playfairDisplay(
                  color: primaryBrown,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete your store audio story? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _storeService.deleteStoreAudioStory(
          _storeDoc!.id,
          _storeData!['audioStoryUrl'] ?? '',
        );
        
        _refreshStoreData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio story deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting audio story: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Store Audio Story',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: primaryBrown,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryBrown),
        actions: [
          if (_storeData != null && _storeData!['audioStoryUrl'] != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteAudioStory,
              tooltip: 'Delete Audio Story',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStoreData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGold))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _refreshStoreData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final hasAudioStory = _storeData != null && 
                         _storeData!['audioStoryUrl'] != null && 
                         _storeData!['audioStoryUrl'].toString().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store info header
          if (_storeData != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, accentGold.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentGold.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
                      color: primaryBrown,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _storeData!['storeName'] ?? 'Your Store',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _storeData!['storeType'] ?? 'Handicrafts',
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryBrown.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasAudioStory ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasAudioStory ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasAudioStory ? Icons.check_circle : Icons.schedule,
                          size: 16,
                          color: hasAudioStory ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasAudioStory ? 'Story Active' : 'No Story',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hasAudioStory ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],

          // Current audio story section (if exists)
          if (hasAudioStory) ...[
            Text(
              'Current Audio Story',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 12),
            
            SellerStoreAudioEditor(
              storeId: _storeDoc!.id,
              storeData: _storeData!,
              onStoryUpdated: _loadStoreData,
              primaryColor: primaryBrown,
              accentColor: accentGold,
            ),
            
            const SizedBox(height: 32),
            
            // Replace story section
            Text(
              'Update Your Story',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record a new audio story to replace the current one. The old story will be permanently deleted.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            // No audio story yet
            Text(
              'Create Your Audio Story',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryBrown,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your personal story with customers to build trust and connection. Your audio story will be automatically transcribed and translated into multiple languages.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Audio recorder
          if (_storeData != null)
            StoreAudioRecorder(
              storeId: _storeDoc!.id,
              storeName: _storeData!['storeName'] ?? 'Your Store',
              onAudioStoryComplete: _onAudioStoryComplete,
              primaryColor: primaryBrown,
              accentColor: accentGold,
            ),

          const SizedBox(height: 32),

          // Benefits section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBrown.withOpacity(0.05), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryBrown.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: accentGold, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Why Add an Audio Story?',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...[
                  '🎯 Build trust with potential customers',
                  '💝 Share your passion and craftsmanship journey',
                  '🌍 Reach customers in their preferred language',
                  '📈 Increase sales through personal connection',
                  '⭐ Stand out from other sellers',
                  '🔊 Let your voice tell your unique story',
                ].map((benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    benefit,
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryBrown.withOpacity(0.8),
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
