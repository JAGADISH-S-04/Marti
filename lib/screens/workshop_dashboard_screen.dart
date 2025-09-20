import 'package:flutter/material.dart';
import '../services/living_workshop_service.dart';
import '../services/artisan_workshop_customization_service.dart';
import 'living_workshop_screen.dart';
import '../widgets/artisan_workshop_editor.dart';
import 'artisan_media_upload_screen.dart';

class WorkshopDashboardScreen extends StatefulWidget {
  final String artisanId;
  final Map<String, dynamic>? existingWorkshopData;

  const WorkshopDashboardScreen({
    Key? key,
    required this.artisanId,
    this.existingWorkshopData,
  }) : super(key: key);

  @override
  State<WorkshopDashboardScreen> createState() => _WorkshopDashboardScreenState();
}

class _WorkshopDashboardScreenState extends State<WorkshopDashboardScreen> {
  final LivingWorkshopService _workshopService = LivingWorkshopService();
  bool _isLoading = true;
  bool _hasExistingWorkshop = false;
  Map<String, dynamic>? _workshopData;

  @override
  void initState() {
    super.initState();
    _checkWorkshopStatus();
  }

  Future<void> _checkWorkshopStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 Checking workshop status for artisan: ${widget.artisanId}');
      
      // First check if workshop exists
      final workshopExists = await _workshopService.workshopExists(widget.artisanId);
      
      if (workshopExists) {
        // Load the existing workshop
        final workshopData = await _workshopService.loadWorkshopContent(widget.artisanId);
        
        if (workshopData != null && workshopData.isNotEmpty) {
          setState(() {
            _hasExistingWorkshop = true;
            _workshopData = workshopData;
            _isLoading = false;
          });
          return;
        }
      }
      
      // Check if we have workshop data from current session
      if (widget.existingWorkshopData != null && widget.existingWorkshopData!.isNotEmpty) {
        setState(() {
          _hasExistingWorkshop = true;
          _workshopData = widget.existingWorkshopData;
          _isLoading = false;
        });
        return;
      }
      
      // No existing workshop found, show creation option
      setState(() {
        _hasExistingWorkshop = false;
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error checking workshop status: $e');
      setState(() {
        _hasExistingWorkshop = false;
        _isLoading = false;
      });
    }
  }

  void _navigateToWorkshop(Map<String, dynamic> workshopData) async {
    // Use pushReplacement to replace this screen with the workshop
    final resolvedId = await _workshopService.resolveWorkshopId(widget.artisanId) ?? widget.artisanId;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LivingWorkshopScreen(
          workshopData: workshopData,
          artisanId: resolvedId,
          allowOwnerEdit: true,
        ),
      ),
    );
  }

  void _navigateToCreateWorkshop() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ArtisanMediaUploadScreen(),
      ),
    ).then((result) {
      // If workshop was created successfully, check status again
      if (result == true || result is Map<String, dynamic>) {
        _checkWorkshopStatus();
      }
    });
  }

  Future<void> _deleteWorkshopAndCreateNew() async {
    // Show confirmation dialog
    final confirmed = await _showDeleteConfirmDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // Get the workshop ID
      final resolvedId = await _workshopService.resolveWorkshopId(widget.artisanId) ?? widget.artisanId;
      
      // Delete the current workshop
      await ArtisanWorkshopCustomizationService.deleteWorkshop(
        workshopId: resolvedId,
        artisanId: widget.artisanId,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workshop deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to create workshop screen
      _navigateToCreateWorkshop();

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete workshop: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workshop'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this workshop?'),
            SizedBox(height: 12),
            Text(
              'This action will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Delete all workshop content and images'),
            Text('• Take you to create a new workshop'),
            Text('• Cannot be undone'),
            SizedBox(height: 12),
            Text(
              'You can start fresh with a completely new workshop.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete & Start New'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading your workshop...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasExistingWorkshop && _workshopData != null) {
      // Show dashboard with options to view or edit
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: Colors.purple,
          title: const Text('Your Workshop', style: TextStyle(color: Colors.white)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _workshopData!['workshopTitle'] ?? _workshopData!['title'] ?? 'Your Living Workshop',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage and preview your interactive workshop experience',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final resolvedId = await _workshopService.resolveWorkshopId(widget.artisanId) ?? widget.artisanId;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LivingWorkshopScreen(
                                workshopData: _workshopData!,
                                artisanId: resolvedId,
                                allowOwnerEdit: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Live Workshop'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
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
                                workshopData: _workshopData!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Workshop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _deleteWorkshopAndCreateNew,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Workshop & Start New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show the create workshop screen
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.create,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 30),
              Text(
                'Create Your Living Workshop',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Transform your workshop into an immersive digital experience! Our AI will analyze your media and create an interactive space where customers can explore your craft and discover your products.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _navigateToCreateWorkshop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Workshop',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkWorkshopStatus,
                child: Text(
                  'Refresh',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}