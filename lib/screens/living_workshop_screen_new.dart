import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../services/product_database_service.dart';
import 'product_detail_screen.dart';

class LivingWorkshopScreen extends StatefulWidget {
  final Map<String, dynamic> workshopData;
  final String artisanId;

  const LivingWorkshopScreen({
    Key? key,
    required this.workshopData,
    required this.artisanId,
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
  
  int _currentChapter = 0;
  bool _isRevealing = false;
  String _currentMood = 'contemplative';
  
  final List<String> _interactiveStory = [
    "In the gentle morning light, skilled hands begin their ancient dance...",
    "Each tool tells a story of generations past, whispering secrets of mastery...",
    "The clay responds to touch, transforming under patient guidance...",
    "Colors blend like memories, each hue carrying the weight of tradition...",
    "As the day unfolds, art comes alive through dedication and love..."
  ];
  
  final Map<String, Color> _moodColors = {
    'contemplative': Color(0xFF2D3142),
    'inspired': Color(0xFF9B4192),
    'focused': Color(0xFF1B4332),
    'joyful': Color(0xFFE9C46A),
    'peaceful': Color(0xFF264653),
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startImmersiveExperience();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut)
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  void _startImmersiveExperience() {
    _fadeController.forward();
    Future.delayed(Duration(milliseconds: 500), () {
      _slideController.forward();
    });
  }

  void _advanceChapter() {
    if (_currentChapter < _interactiveStory.length - 1) {
      setState(() {
        _isRevealing = true;
        _currentMood = ['contemplative', 'inspired', 'focused', 'joyful', 'peaceful'][_currentChapter];
      });
      
      _slideController.reverse().then((_) {
        setState(() {
          _currentChapter++;
          _isRevealing = false;
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _moodColors[_currentMood]!,
                  _moodColors[_currentMood]!.withOpacity(0.8),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with artisan name
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Master Artisan\'s Workshop',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    SizedBox(height: 60),
                    
                    // Main story content
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildInteractiveStoryCard(),
                        ),
                      ),
                    ),
                    
                    // Interactive elements at bottom
                    _buildInteractiveControls(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveStoryCard() {
    return Container(
      padding: EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Chapter indicator
          Text(
            'Chapter ${_currentChapter + 1} of ${_interactiveStory.length}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w300,
            ),
          ),
          
          SizedBox(height: 40),
          
          // Main story text
          Text(
            _interactiveStory[_currentChapter],
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              height: 1.6,
              color: Colors.white,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: 60),
          
          // Interactive hotspots simulation
          _buildInteractiveHotspots(),
        ],
      ),
    );
  }

  Widget _buildInteractiveHotspots() {
    final List<Map<String, String>> chapterHotspots = [
      {'icon': '🌅', 'title': 'Morning Light', 'hint': 'Feel the warmth'},
      {'icon': '🔨', 'title': 'Ancient Tools', 'hint': 'Touch history'},
      {'icon': '🏺', 'title': 'Living Clay', 'hint': 'Shape dreams'},
      {'icon': '🎨', 'title': 'Color Symphony', 'hint': 'Mix emotions'},
      {'icon': '💖', 'title': 'Heart Work', 'hint': 'Discover passion'},
    ];
    
    final currentHotspots = chapterHotspots[_currentChapter];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildHotspotButton(
          currentHotspots['icon']!,
          currentHotspots['title']!,
          currentHotspots['hint']!,
        ),
        _buildHotspotButton('✨', 'Inspiration', 'Feel the magic'),
        _buildHotspotButton('🤲', 'Touch', 'Connect deeply'),
      ],
    );
  }

  Widget _buildHotspotButton(String icon, String title, String hint) {
    return GestureDetector(
      onTap: () => _showHotspotDetail(title, hint),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveControls() {
    return Column(
      children: [
        // Progress indicator
        Container(
          height: 4,
          margin: EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_currentChapter + 1) / _interactiveStory.length,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        
        SizedBox(height: 30),
        
        // Navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            if (_currentChapter > 0)
              _buildNavButton(
                Icons.arrow_back,
                'Previous',
                () {
                  setState(() {
                    _currentChapter--;
                    _currentMood = ['contemplative', 'inspired', 'focused', 'joyful', 'peaceful'][_currentChapter];
                  });
                  _slideController.reverse().then((_) => _slideController.forward());
                },
              ),
            
            Spacer(),
            
            // Next/Continue button
            if (_currentChapter < _interactiveStory.length - 1)
              _buildNavButton(
                Icons.arrow_forward,
                'Continue Journey',
                _advanceChapter,
              )
            else
              _buildNavButton(
                Icons.favorite,
                'Complete Experience',
                () => _showCompletionDialog(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHotspotDetail(String title, String hint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _moodColors[_currentMood]!.withOpacity(0.95),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: 16),
            Text(
              hint,
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Text(
              'This moment invites you to pause and connect with the artisan\'s world. Feel the texture, hear the sounds, breathe in the atmosphere of creation.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text('Continue Experience'),
            ),
          ],
        ),
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
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Return Home',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentChapter = 0;
                _currentMood = 'contemplative';
              });
              _slideController.reset();
              _slideController.forward();
            },
            child: Text(
              'Experience Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
