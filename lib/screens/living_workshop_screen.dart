import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/living_workshop_service.dart';
import 'artisan_media_upload_screen.dart';
import '../widgets/artisan_workshop_editor.dart';

class LivingWorkshopScreen extends StatefulWidget {
  final Map<String, dynamic> workshopData;
  final String artisanId;
  final bool allowOwnerEdit;

  const LivingWorkshopScreen({
    Key? key,
    required this.workshopData,
    required this.artisanId,
    this.allowOwnerEdit = false,
  }) : super(key: key);

  @override
  _LivingWorkshopScreenState createState() => _LivingWorkshopScreenState();
}

class _LivingWorkshopScreenState extends State<LivingWorkshopScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final LivingWorkshopService _workshopService = LivingWorkshopService();
  
  int _currentChapter = 0;
  String _currentMood = 'contemplative';
  List<String> _interactiveStory = [];
  String _workshopTitle = 'Living Workshop';
  String _emotionalTheme = 'connection';
  bool _contentLoaded = false;
  
  final Map<String, Color> _moodColors = {
    'contemplative': const Color(0xFF2D3142),
    'inspired': const Color(0xFF9B4192),
    'focused': const Color(0xFF1B4332),
    'joyful': const Color(0xFFE9C46A),
    'peaceful': const Color(0xFF264653),
    'devotion': const Color(0xFF8B4F75),
    'tranquility': const Color(0xFF5A8A8A),
    'passion': const Color(0xFFD63031),
    'wisdom': const Color(0xFF74B9FF),
    'wonder': const Color(0xFFB983FF),
    'reverence': const Color(0xFF6C7B7F),
    'curiosity': const Color(0xFF00B894),
    'connection': const Color(0xFFFEBC2C),
  };

  bool _isGeneratingAI = false;
  Map<String, dynamic>? _aiGeneratedContent;
  Map<String, dynamic>? _liveWorkshopData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _workshopSub;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeWorkshopContent();
    _startImmersiveExperience();
    _startLiveUpdates();
  }
  Future<void> _startLiveUpdates() async {
    try {
      // Prefer explicit workshopId when provided; else resolve by artisanId
      final explicitWorkshopId = (widget.workshopData['workshop_id'] ?? widget.workshopData['id'])?.toString();
      final resolvedId = explicitWorkshopId ?? (await _workshopService.resolveWorkshopId(widget.artisanId) ?? widget.artisanId);
      _workshopSub?.cancel();
      _workshopSub = FirebaseFirestore.instance
          .collection('living_workshops')
          .doc(resolvedId)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        if (snap.exists && snap.data() != null) {
          setState(() {
            _liveWorkshopData = snap.data()!;
          });
        }
      }, onError: (e) {
        debugPrint('⚠️ Live updates error: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Failed to start live updates: $e');
    }
  }

  Future<void> _initializeWorkshopContent() async {
    setState(() {
      _isGeneratingAI = true;
    });

    try {
      // Add timeout to prevent infinite loading
      final timeoutDuration = const Duration(seconds: 10);
      
      // First, try to load existing workshop content for this artisan
      print('🔍 Checking for existing workshop content for artisan: ${widget.artisanId}');
      
      final savedContent = await _workshopService.loadWorkshopContent(widget.artisanId)
          .timeout(timeoutDuration, onTimeout: () {
        print('⏰ Loading saved content timed out, proceeding with new generation');
        return null;
      });
      
      if (savedContent != null && savedContent.isNotEmpty) {
        print('✅ Found saved workshop content, loading...');
        _loadSavedWorkshopContent(savedContent);
        _liveWorkshopData = savedContent;
        setState(() {
          _contentLoaded = true;
          _isGeneratingAI = false;
        });
        return;
      }
      
      // Check if we have workshop data to work with (from current session or parameters)
      final hasWorkshopData = widget.workshopData.isNotEmpty && 
                              (widget.workshopData['hotspots'] != null || 
                               widget.workshopData['chapter_stories'] != null ||
                               widget.workshopData['ui_descriptions'] != null ||
                               widget.workshopData['workshopTitle'] != null);
      
      if (hasWorkshopData) {
        // Use existing workshop data and extract stories
        print('✅ Using provided workshop data to create experience');
        _extractEmotionalStories();
        
        // Save this workshop data for future use
        await _saveWorkshopData(widget.workshopData);
        _liveWorkshopData = Map<String, dynamic>.from(widget.workshopData);
        
        setState(() {
          _contentLoaded = true;
          _isGeneratingAI = false;
        });
        return;
      }
      
      // Check if this is a newly created workshop that needs to be saved
      print('🔍 Checking if workshop was created but not yet saved...');
      
      // Try to extract any existing content from the widget data
      _extractEmotionalStories();
      
      if (_interactiveStory.isNotEmpty || _workshopTitle != 'Living Workshop') {
        // We have some content, save it and continue
        print('✅ Found some workshop content, saving and displaying...');
        await _saveWorkshopData({
          'workshopTitle': _workshopTitle,
          'emotionalTheme': _emotionalTheme,
          'chapter_stories': _interactiveStory,
          'artisanId': widget.artisanId,
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'active',
        });
        
        setState(() {
          _contentLoaded = true;
          _isGeneratingAI = false;
        });
        return;
      }
      
      // If no saved content exists and no workshop data, navigate to creation screen
      print('🚀 No saved workshop found, redirecting to creation screen...');
      // Navigate immediately using post frame callback to ensure widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToWorkshopCreation();
      });
      
    } catch (e) {
      print('❌ Error initializing workshop content: $e');
      // Try to extract from existing data as fallback
      _extractEmotionalStories();
      if (_interactiveStory.isNotEmpty) {
        setState(() {
          _isGeneratingAI = false;
          _contentLoaded = true;
        });
      } else {
        // If still no content, navigate to creation screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToWorkshopCreation();
        });
      }
    }
  }

  void _navigateToWorkshopCreation() {
    // Import and navigate directly to the workshop creation screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ArtisanMediaUploadScreen(),
      ),
    ).then((result) {
      // If workshop was created successfully, reload this screen
      if (result == true) {
        _initializeWorkshopContent();
      }
    });
  }

  void _loadSavedWorkshopContent(Map<String, dynamic> savedContent) {
    try {
      _workshopTitle = savedContent['workshopTitle'] ?? savedContent['title'] ?? 'Living Workshop';
      _emotionalTheme = savedContent['emotionalTheme'] ?? savedContent['emotional_theme'] ?? 'connection';
      _currentMood = _emotionalTheme;
      
      // Try to load interactive story from multiple possible fields
      List<String> storyChapters = [];
      
      // 1. First try the saved interactiveStory field (from persistence)
      final savedStory = savedContent['interactiveStory'];
      if (savedStory is List && savedStory.isNotEmpty) {
        storyChapters = savedStory.cast<String>();
        print('✅ Loaded story from interactiveStory field: ${storyChapters.length} chapters');
      }
      
      // 2. If that's empty, try chapter_stories (from AI generation)
      if (storyChapters.isEmpty) {
        final chapterStories = savedContent['chapter_stories'];
        if (chapterStories is List && chapterStories.isNotEmpty) {
          storyChapters = chapterStories.cast<String>();
          print('✅ Loaded story from chapter_stories field: ${storyChapters.length} chapters');
        }
      }
      
      // 3. If still empty, try ui_descriptions (fallback)
      if (storyChapters.isEmpty) {
        final uiDescriptions = savedContent['ui_descriptions'];
        if (uiDescriptions is List && uiDescriptions.isNotEmpty) {
          storyChapters = uiDescriptions.cast<String>();
          print('✅ Loaded story from ui_descriptions field: ${storyChapters.length} chapters');
        }
      }
      
      // 4. If still empty, extract from hotspots
      if (storyChapters.isEmpty) {
        final hotspots = savedContent['hotspots'];
        if (hotspots is List && hotspots.isNotEmpty) {
          storyChapters = hotspots.map<String>((hotspot) {
            final description = hotspot['description'] ?? '';
            final touchPrompt = hotspot['touchPrompt'] ?? '';
            return description.isNotEmpty ? description : touchPrompt;
          }).where((story) => story.isNotEmpty).toList();
          print('✅ Extracted story from hotspots: ${storyChapters.length} chapters');
        }
      }
      
      _interactiveStory = storyChapters;
      
      // Load generated content
      final savedGeneratedContent = savedContent['generatedContent'] ?? savedContent;
      if (savedGeneratedContent is Map<String, dynamic>) {
        _aiGeneratedContent = savedGeneratedContent;
      }
      
      print('✅ Loaded saved workshop content: ${_interactiveStory.length} chapters');
      print('📋 Workshop title: $_workshopTitle');
      print('🎨 Emotional theme: $_emotionalTheme');
      
      // If we still have no story content, use the full saved content as workshop data
      if (_interactiveStory.isEmpty) {
        print('⚠️ No story chapters found, extracting from workshop data...');
        widget.workshopData.addAll(savedContent);
        _extractEmotionalStories();
      }
      
    } catch (e) {
      print('❌ Error loading saved content: $e');
      // Fallback to extracting from workshop data
      _extractEmotionalStories();
    }
  }

  Future<void> _saveGeneratedContent() async {
    try {
      if (_aiGeneratedContent != null && _interactiveStory.isNotEmpty) {
        await _workshopService.saveWorkshopContent(
          artisanId: widget.artisanId,
          originalWorkshopData: widget.workshopData,
          generatedContent: _aiGeneratedContent!,
          interactiveStory: _interactiveStory,
          workshopTitle: _workshopTitle,
          emotionalTheme: _emotionalTheme,
        );
        
        setState(() {
          _contentLoaded = true;
        });
        
        print('✅ Workshop content saved successfully for artisan: ${widget.artisanId}');
      }
    } catch (e) {
      print('❌ Error saving generated content: $e');
      // Continue anyway, user can still experience the workshop
    }
  }

  /// Save workshop data to ensure it persists for future visits
  Future<void> _saveWorkshopData(Map<String, dynamic> workshopData) async {
    try {
      await _workshopService.saveWorkshopContent(
        artisanId: widget.artisanId,
        originalWorkshopData: workshopData,
        generatedContent: workshopData,
        interactiveStory: _interactiveStory,
        workshopTitle: _workshopTitle,
        emotionalTheme: _emotionalTheme,
      );
      
      print('✅ Workshop data saved successfully for artisan: ${widget.artisanId}');
    } catch (e) {
      print('❌ Error saving workshop data: $e');
      // Continue anyway, user can still experience the workshop
    }
  }

  Future<void> _generateAIContentAndStories() async {
    try {
      // 🔥 GOD-LEVEL AI GENERATION: Generate REAL AI content
      print('🚀 GOD-MODE: Starting AI content generation...');
      
      // For now, use fallback content generation since we don't have the required File objects
      // TODO: Implement proper file handling for workshop video, photos, and audio
      _aiGeneratedContent = await _generateFallbackContent();
      
      print('🎨 AI Content Generated: ${_aiGeneratedContent}');
      
      // Extract AI-generated stories
      _extractEmotionalStories();
      
    } catch (e) {
      print('❌ AI Generation Error: $e');
      // Fallback to existing data extraction
      _extractEmotionalStories();
    }
  }

  Future<Map<String, dynamic>> _generateFallbackContent() async {
    // Generate fallback content based on available workshop data
    return {
      'ai_images': [
        {
          'url': 'https://via.placeholder.com/800x600/2D3142/FFFFFF?text=Workshop+Moment+1',
          'description': 'The artisan\'s hands shaping clay with deep concentration',
          'emotion': 'contemplative'
        },
        {
          'url': 'https://via.placeholder.com/800x600/9B4192/FFFFFF?text=Workshop+Moment+2',
          'description': 'The moment when creativity flows through ancient techniques',
          'emotion': 'inspired'
        }
      ],
      'emotional_story': widget.workshopData['emotional_story'] ?? 'A beautiful journey of craftsmanship and soul.',
      'workshop_theme': widget.workshopData['emotionalTheme'] ?? 'connection'
    };
  }

  void _extractEmotionalStories() {
    // Extract stories from workshop data or use beautiful defaults
    final workshopData = widget.workshopData;
    
    _workshopTitle = workshopData['workshopTitle'] ?? 'Where Souls Meet Art';
    _emotionalTheme = workshopData['emotionalTheme'] ?? 'connection';
    _currentMood = _emotionalTheme;
    
    // 🔥 PRIORITY 1: Use FRESH AI-generated content
    if (_aiGeneratedContent != null) {
      final chapterStories = _aiGeneratedContent!['chapter_stories'] as List?;
      if (chapterStories != null && chapterStories.isNotEmpty) {
        _interactiveStory = chapterStories.cast<String>();
        print('✨ Using FRESH AI-generated chapter stories: ${_interactiveStory.length} chapters');
        return;
      }
    }
    
    // PRIORITY 2: Extract stories from existing AI-generated chapter stories
    final chapterStories = workshopData['chapter_stories'] as List?;
    if (chapterStories != null && chapterStories.isNotEmpty) {
      _interactiveStory = chapterStories.cast<String>();
      print('✨ Using existing AI-generated chapter stories: ${_interactiveStory.length} chapters');
    } else {
      // Fallback to UI descriptions
      final uiDescriptions = workshopData['ui_descriptions'] as List?;
      if (uiDescriptions != null && uiDescriptions.isNotEmpty) {
        _interactiveStory = uiDescriptions.cast<String>();
        print('✨ Using AI-generated emotional descriptions: ${_interactiveStory.length} stories');
      } else {
        // Create story from hotspots or use meaningful defaults
        final hotspots = workshopData['hotspots'] as List<dynamic>? ?? [];
        
        if (hotspots.isNotEmpty) {
          _interactiveStory = hotspots.map<String>((hotspot) {
            final description = hotspot['description'] ?? '';
            final touchPrompt = hotspot['touchPrompt'] ?? '';
            return description.isNotEmpty ? description : touchPrompt;
          }).where((story) => story.isNotEmpty).toList();
        }
      }
    }
    
    // Fallback to soul-touching default stories if none exist
    if (_interactiveStory.isEmpty) {
      _interactiveStory = [
        "Here, in this sacred space, dreams take physical form through patient hands and an open heart...",
        "Every tool holds the memory of countless creations, each one a bridge between the artisan's soul and yours...",
        "Feel the whispered secrets of ancient wisdom, passed down through generations of makers who understood that art is love made visible...",
        "Watch as raw materials surrender to skilled hands, transforming into something that will carry meaning far beyond its physical form...",
        "In this moment, you are witnessing the sacred act of creation - where human hands transform dreams into reality..."
      ];
    }
    
    if (_interactiveStory.isEmpty) {
      _interactiveStory = ["In this moment, you are witnessing the sacred act of creation - where human hands transform dreams into reality..."];
    }
    
    print('✨ Final story count: ${_interactiveStory.length} emotional stories');
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  void _startImmersiveExperience() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  void _advanceChapter() {
    if (_currentChapter < _interactiveStory.length - 1) {
      setState(() {
        // Cycle through emotional moods based on the story content
        final emotionalMoods = ['contemplative', 'inspired', 'focused', 'joyful', 'peaceful', 
                              'devotion', 'tranquility', 'passion', 'wisdom', 'wonder'];
        _currentMood = emotionalMoods[_currentChapter % emotionalMoods.length];
      });
      
      _slideController.reverse().then((_) {
        setState(() {
          _currentChapter++;
        });
        _slideController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _moodColors[_currentMood],
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _moodColors[_currentMood]!,
                  _moodColors[_currentMood]!.withOpacity(0.8),
                ],
              ),
            ),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildWorkshopContent(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: _ownerEditFab(),
    );
  }

  Widget? _ownerEditFab() {
    try {
      if (!widget.allowOwnerEdit) return null;
      final currentUserId = _workshopService.currentUserId;
      final baseArtisanId = widget.artisanId.endsWith('_content')
          ? widget.artisanId.substring(0, widget.artisanId.length - '_content'.length)
          : widget.artisanId;
      if (currentUserId == null || currentUserId != baseArtisanId) return null;
    } catch (_) {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: () async {
        final resolvedId = await _workshopService.resolveWorkshopId(widget.artisanId) ?? widget.artisanId;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtisanWorkshopEditor(
              workshopId: resolvedId,
              artisanId: resolvedId.endsWith('_content')
                  ? resolvedId.substring(0, resolvedId.length - '_content'.length)
                  : resolvedId,
              workshopData: _aiGeneratedContent ?? widget.workshopData,
            ),
          ),
        );
      },
      icon: const Icon(Icons.edit),
      label: const Text('Edit'),
      backgroundColor: Colors.purple,
    );
  }

  Widget _buildWorkshopContent() {
    // 🔥 GOD-LEVEL UI: Show AI generation progress
    if (_isGeneratingAI) {
      return _buildAIGenerationScreen();
    }
    
    // Guard against empty interactive story to prevent crashes
    if (_interactiveStory.isEmpty) {
      return _buildLoadingScreen();
    }
    
    return SafeArea(
      child: Column(
        children: [
          // Header with artisan connection
          _buildEmotionalHeader(),
          
          // Main immersive workshop content
          Expanded(
            child: _buildImmersiveWorkshop(),
          ),
          
          // Navigation controls
          _buildNavigationControls(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Preparing Your Workshop',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Setting up your immersive workshop experience...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIGenerationScreen() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI generation animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _contentLoaded ? Icons.cached : Icons.auto_awesome,
                      size: 48,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _contentLoaded ? 'Loading Your Saved Experience' : 'Creating Your AI Experience',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _contentLoaded 
                  ? 'Retrieving your personalized workshop content...'
                  : 'Gemini AI is crafting personalized stories and realistic images just for you...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _contentLoaded ? Icons.cloud_download : Icons.smart_toy,
                    size: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _contentLoaded ? 'Loading Saved Content' : 'Dual-Model AI Processing',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Skip button for users stuck on loading
            TextButton.icon(
              onPressed: () {
                print('🚨 User requested to skip loading, using fallback content');
                _extractEmotionalStories();
                setState(() {
                  _isGeneratingAI = false;
                  _contentLoaded = true;
                });
              },
              icon: Icon(
                Icons.skip_next,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
              label: Text(
                'Skip Loading',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios, color: Colors.white.withOpacity(0.8)),
              ),
              Expanded(
                child: Text(
                  _workshopTitle,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_contentLoaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done,
                        size: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(Icons.favorite_border, color: Colors.white.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '~ connection ~',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmersiveWorkshop() {
    // Guard against empty story to prevent crashes
    if (_interactiveStory.isEmpty) {
      return Center(
        child: Text(
          'Loading workshop content...',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Chapter indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(
              'Chapter ${_currentChapter + 1} of ${_interactiveStory.length}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // AI-Generated Chapter Image
          _buildChapterImage(),
          
          const SizedBox(height: 24),
          
          // Preview of next chapter's AI image (if available)
          if (_currentChapter < _interactiveStory.length - 1) _buildNextChapterPreview(),
          
          const SizedBox(height: 40),
          
          // Main story text
          Text(
            _interactiveStory[_currentChapter],
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              height: 1.6,
              color: Colors.white,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 60),
          
          // Interactive hotspots simulation
          _buildInteractiveHotspots(),
        ],
      ),
    );
  }

  Widget _buildChapterImage() {
    // Prefer persisted workshop images (which include artisan uploads);
    // fall back to AI content only if workshop data is missing.
    final data = _liveWorkshopData ?? widget.workshopData;
    dynamic chapterImages = data['chapter_images'] ?? _aiGeneratedContent?['chapter_images'];
    final useSource = data['chapter_images'] != null ? 'workshop-live' : (_aiGeneratedContent != null ? 'ai' : 'none');
    print('🎨 Using $useSource chapter images: ${chapterImages is List ? chapterImages.length : (chapterImages is Map ? chapterImages.length : 0)}');
    print('🔍 Chapter images type: ${chapterImages?.runtimeType}');
    
    // Check if we have chapter images and the current chapter exists
    bool hasChapterImage = false;
    if (chapterImages != null) {
      if (chapterImages is Map) {
        hasChapterImage = chapterImages.containsKey(_currentChapter.toString()) || 
                         chapterImages.containsKey('$_currentChapter');
      } else if (chapterImages is List) {
        hasChapterImage = _currentChapter < chapterImages.length;
      }
    }
    
    if (hasChapterImage) {
      dynamic currentImage;
      
      // Handle both List and Map formats for chapter images
      if (chapterImages is Map) {
        // If it's a Map, try to access with string key
        print('🔍 Looking for chapter $_currentChapter in Map keys: ${chapterImages.keys.toList()}');
        currentImage = chapterImages[_currentChapter.toString()] ?? chapterImages['$_currentChapter'];
        print('🔍 Found currentImage for chapter $_currentChapter: ${currentImage != null ? 'YES' : 'NO'}');
        if (currentImage != null && currentImage is Map) {
          print('🔍 Image data: artisan_url=${currentImage['artisan_image_url']}, generated_url=${currentImage['generated_image_url']}');
        }
      } else if (chapterImages is List) {
        // If it's a List, access with integer index
        currentImage = chapterImages[_currentChapter];
      } else {
        currentImage = null;
      }
      
      if (currentImage == null) {
        print('❌ No chapter image found for chapter $_currentChapter');
        return Container(
          height: 300,
          width: double.infinity,
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.image_not_supported, 
                       color: Colors.grey[600], size: 50),
          ),
        );
      }
      
      // Handle different data formats for currentImage
      String imagePrompt = '';
      String imageTitle = 'Chapter ${_currentChapter + 1}';
      String description = '';
      String imageUrl = '';
      
      if (currentImage is String) {
        // If currentImage is just a URL string
        imageUrl = currentImage;
        print('🖼️ Using simple image URL: $imageUrl');
      } else if (currentImage is Map) {
        // If currentImage is a Map with detailed properties
        imagePrompt = currentImage['image_prompt'] ?? '';
        imageTitle = currentImage['title'] ?? 'Chapter ${_currentChapter + 1}';
        description = currentImage['description'] ?? '';
        
        // Prefer artisan uploaded image, then generated image, else placeholder
        final artisanUrl = currentImage['artisan_image_url'];
        final generatedUrl = currentImage['generated_image_url'];
        if (artisanUrl != null && artisanUrl.toString().isNotEmpty) {
          imageUrl = artisanUrl.toString();
          print('🖼️ Using artisan-uploaded image: $imageUrl');
        } else if (generatedUrl != null && generatedUrl.toString().isNotEmpty) {
          imageUrl = generatedUrl.toString();
          print('🖼️ Using AI-generated image: $imageUrl');
        } else {
          // Enhanced placeholder with better diversity
          final promptHash = imagePrompt.hashCode.abs();
          final seedValue = promptHash % 1000 + (_currentChapter * 137);
          imageUrl = 'https://picsum.photos/400/300?random=$seedValue';
          print('🖼️ Using enhanced placeholder for: $imagePrompt');
        }
      } else {
        // Fallback for unexpected data type
        imageUrl = 'https://picsum.photos/400/300?random=${_currentChapter * 42}';
        print('🖼️ Using fallback placeholder for unexpected data type: ${currentImage.runtimeType}');
      }
      
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // AI-Generated Image (using placeholder service for now)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: _moodColors[_currentMood]?.withOpacity(0.3),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.7),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _moodColors[_currentMood]?.withOpacity(0.8) ?? Colors.grey.withOpacity(0.8),
                          _moodColors[_currentMood]?.withOpacity(0.6) ?? Colors.grey.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI Generated',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // Gradient overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              
              // AI Image Details Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.smart_toy,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AI Generated',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        imageTitle,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Fallback chapter-themed AI placeholder
    final chapterThemes = [
      {'icon': '🌅', 'title': 'The Sacred Beginning', 'seed': 1001},
      {'icon': '🔨', 'title': 'The Dance of Tools', 'seed': 1002}, 
      {'icon': '✨', 'title': 'The Transformation', 'seed': 1003},
      {'icon': '💫', 'title': 'The Soul Emerges', 'seed': 1004},
      {'icon': '💖', 'title': 'The Legacy Lives', 'seed': 1005},
    ];
    
    final currentTheme = chapterThemes[_currentChapter % chapterThemes.length];
    final fallbackImageUrl = 'https://picsum.photos/400/300?random=${currentTheme['seed']}&blur=1';
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fallback AI-style image
            Image.network(
              fallbackImageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _moodColors[_currentMood]?.withOpacity(0.8) ?? Colors.grey.withOpacity(0.8),
                        _moodColors[_currentMood]?.withOpacity(0.6) ?? Colors.grey.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _moodColors[_currentMood]?.withOpacity(0.8) ?? Colors.grey.withOpacity(0.8),
                        _moodColors[_currentMood]?.withOpacity(0.6) ?? Colors.grey.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentTheme['icon'] as String,
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI Generated',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Gradient overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            
            // Chapter details overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI Generated',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentTheme['title'] as String,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chapter ${_currentChapter + 1} of the artisan\'s journey',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
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

  Widget _buildNextChapterPreview() {
    // Prefer live/persisted workshop images; fall back to AI content if absent
    final data = _liveWorkshopData ?? widget.workshopData;
    final dynamic chapterImages = data['chapter_images'] ?? _aiGeneratedContent?['chapter_images'];
    final nextChapter = _currentChapter + 1;
    
    // Check if we have chapter images and the next chapter exists
    bool hasNextChapterImage = false;
    if (chapterImages != null) {
      if (chapterImages is Map) {
        hasNextChapterImage = chapterImages.containsKey(nextChapter.toString()) || 
                             chapterImages.containsKey('$nextChapter');
      } else if (chapterImages is List) {
        hasNextChapterImage = nextChapter < chapterImages.length;
      }
    }
    
    if (hasNextChapterImage) {
      dynamic nextImage;
      
      // Handle both List and Map formats for chapter images
      if (chapterImages is Map) {
        // If it's a Map, try to access with string key
        print('🔍 Next chapter: Looking for chapter $nextChapter in Map keys: ${chapterImages.keys.toList()}');
        nextImage = chapterImages[nextChapter.toString()] ?? chapterImages['$nextChapter'];
        print('🔍 Found nextImage for chapter $nextChapter: ${nextImage != null ? 'YES' : 'NO'}');
      } else if (chapterImages is List) {
        // If it's a List, access with integer index
        nextImage = chapterImages[nextChapter];
      }
      
      if (nextImage == null) {
        return Container(); // Return empty container if no next image
      }
      
      // Handle different data formats for nextImage
      String imageTitle = 'Chapter ${nextChapter + 1}';
      String imageUrl = '';
      
      if (nextImage is String) {
        // If nextImage is just a URL string
        imageUrl = nextImage;
        print('🖼️ Next chapter using simple image URL: $imageUrl');
      } else if (nextImage is Map) {
        // If nextImage is a Map with detailed properties
        imageTitle = nextImage['title'] ?? 'Chapter ${nextChapter + 1}';
        final promptHash = (nextImage['image_prompt'] ?? '').hashCode.abs() + 100;
        // Prefer artisan image, then generated, else placeholder
        imageUrl = nextImage['artisan_image_url'] ??
                   nextImage['generated_image_url'] ??
                   'https://picsum.photos/300/200?random=$promptHash&blur=1';
      } else {
        // Fallback for unexpected data type
        imageUrl = 'https://picsum.photos/300/200?random=${nextChapter * 42}&blur=1';
        print('🖼️ Next chapter using fallback placeholder for unexpected data type: ${nextImage.runtimeType}');
      }
      
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _moodColors[_currentMood]?.withOpacity(0.6) ?? Colors.grey.withOpacity(0.6),
                          _moodColors[_currentMood]?.withOpacity(0.4) ?? Colors.grey.withOpacity(0.4),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white.withOpacity(0.7),
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'NEXT',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imageTitle,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container();
  }

  Widget _buildInteractiveHotspots() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.touch_app,
            color: Colors.white.withOpacity(0.7),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Feel the Story',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Touch the screen to sense the artisan\'s energy and emotions flowing through their work',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationControls() {
    // Guard against empty story
    if (_interactiveStory.isEmpty) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous chapter
          if (_currentChapter > 0)
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentChapter--;
                  final emotionalMoods = ['contemplative', 'inspired', 'focused', 'joyful', 'peaceful'];
                  _currentMood = emotionalMoods[_currentChapter % emotionalMoods.length];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios, 
                         color: Colors.white.withOpacity(0.8), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Previous',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 80),
          
          // Chapter progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentChapter + 1} / ${_interactiveStory.length}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Next chapter or completion
          if (_currentChapter < _interactiveStory.length - 1)
            GestureDetector(
              onTap: _advanceChapter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, 
                         color: Colors.white, size: 16),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _showCompletionDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Complete',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.favorite, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _moodColors[_currentMood],
        title: Text(
          'Journey Complete',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        content: Text(
          'You\'ve experienced the artisan\'s world through all its beautiful moments. The connection you\'ve made will last forever.',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.9),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Continue Shopping',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _workshopSub?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
