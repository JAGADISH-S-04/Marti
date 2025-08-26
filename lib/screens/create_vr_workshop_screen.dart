import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../vr_workshop_experience.dart'; // Ensure this file exports the VRWorkshopExperience class
import 'package:firebase_auth/firebase_auth.dart';

class CreateVRWorkshopScreen extends StatefulWidget {
  const CreateVRWorkshopScreen({super.key});

  @override
  _CreateVRWorkshopScreenState createState() => _CreateVRWorkshopScreenState();
}

class _CreateVRWorkshopScreenState extends State<CreateVRWorkshopScreen> {
  final _formKey = GlobalKey<FormState>();
  final VRWorkshopExperience _vrWorkshopExperience = VRWorkshopExperience();

  String _workshopTitle = '';
  String _craftTechnique = '';
  final List<String> _processSteps = [''];
  final List<File> _stepVideos = [];
  final List<File> _vrAssets = [];
  final Map<String, dynamic> _environmentSettings = {
    'type': 'traditional_workshop',
    'lighting': 'natural_daylight',
    'atmosphere': 'peaceful',
  };

  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickVideo(int index) async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        if (_stepVideos.length > index) {
          _stepVideos[index] = File(video.path);
        } else {
          _stepVideos.add(File(video.path));
        }
      });
    }
  }

  Future<void> _pickVrAsset() async {
    final XFile? asset = await _picker.pickImage(source: ImageSource.gallery);
    if (asset != null) {
      setState(() {
        _vrAssets.add(File(asset.path));
      });
    }
  }

  void _addProcessStep() {
    setState(() {
      _processSteps.add('');
    });
  }

  void _removeProcessStep(int index) {
    setState(() {
      _processSteps.removeAt(index);
      if (_stepVideos.length > index) {
        _stepVideos.removeAt(index);
      }
    });
  }

  Future<void> _createWorkshop() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('You must be logged in to create a workshop.');
        }

        // Use a placeholder for productId if you don't have one yet
        String productId = 'placeholder_product_id';

        await _vrWorkshopExperience.createVRWorkshop(
          artisanId: user.uid,
          productId: productId,
          workshopTitle: _workshopTitle,
          craftTechnique: _craftTechnique,
          processSteps: _processSteps,
          stepVideos: _stepVideos,
          vrAssets: _vrAssets,
          environmentSettings: _environmentSettings,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VR Workshop created successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create workshop: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create VR Workshop', style: GoogleFonts.playfairDisplay()),
        backgroundColor: Colors.purple[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Workshop Title'),
                      validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
                      onSaved: (value) => _workshopTitle = value!,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Craft Technique'),
                      validator: (value) => value!.isEmpty ? 'Please enter a technique' : null,
                      onSaved: (value) => _craftTechnique = value!,
                    ),
                    const SizedBox(height: 20),
                    Text('Process Steps', style: Theme.of(context).textTheme.titleLarge),
                    ..._buildProcessStepFields(),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Step'),
                      onPressed: _addProcessStep,
                    ),
                    const SizedBox(height: 20),
                    Text('VR Assets', style: Theme.of(context).textTheme.titleLarge),
                    ElevatedButton.icon(
                      onPressed: _pickVrAsset,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add VR Asset'),
                    ),
                    Wrap(
                      children: _vrAssets.map((asset) => Chip(label: Text(asset.path.split('/').last))).toList(),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _createWorkshop,
                      child: const Text('Create Workshop'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildProcessStepFields() {
    return List.generate(_processSteps.length, (index) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _processSteps[index],
                  decoration: InputDecoration(labelText: 'Step ${index + 1}'),
                  onChanged: (value) => _processSteps[index] = value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeProcessStep(index),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _pickVideo(index),
            icon: const Icon(Icons.video_library),
            label: Text('Upload Video for Step ${index + 1}'),
          ),
          if (_stepVideos.length > index)
            Text('Video selected: ${_stepVideos[index].path.split('/').last}'),
        ],
      );
    });
  }
}

class VRWorkshopExperience {
  Future<void> createVRWorkshop({
    required String artisanId,
    required String productId,
    required String workshopTitle,
    required String craftTechnique,
    required List<String> processSteps,
    required List<File> stepVideos,
    required List<File> vrAssets,
    required Map<String, dynamic> environmentSettings,
  }) async {
    // TODO: Implement VR workshop creation logic
    // This could involve uploading files to Firebase Storage,
    // saving metadata to Firestore, etc.
    
    // Simulate async operation
    await Future.delayed(Duration(seconds: 2));
    
    // For now, just print the workshop details
    print('Creating VR Workshop: $workshopTitle');
    print('Craft Technique: $craftTechnique');
    print('Process Steps: ${processSteps.length}');
    print('Step Videos: ${stepVideos.length}');
    print('VR Assets: ${vrAssets.length}');
    print('Environment: $environmentSettings');
  }
}
