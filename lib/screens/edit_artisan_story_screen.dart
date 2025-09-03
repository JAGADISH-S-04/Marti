import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/gemini_service.dart';

class EditArtisanStoryScreen extends StatefulWidget {
  final Product product;

  const EditArtisanStoryScreen({Key? key, required this.product}) : super(key: key);

  @override
  _EditArtisanStoryScreenState createState() => _EditArtisanStoryScreenState();
}

class _EditArtisanStoryScreenState extends State<EditArtisanStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inspirationController = TextEditingController();
  final _materialsOriginController = TextEditingController();
  final _craftingProcessController = TextEditingController();

  List<File> _processImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if data already exists
    final ingredients = widget.product.storyIngredients;
    if (ingredients != null) {
      _inspirationController.text = ingredients['inspiration'] ?? '';
      _materialsOriginController.text = ingredients['materialsOrigin'] ?? '';
      _craftingProcessController.text = ingredients['craftingProcess'] ?? '';
    }
  }

  @override
  void dispose() {
    _inspirationController.dispose();
    _materialsOriginController.dispose();
    _craftingProcessController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(limit: 3);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _processImages = pickedFiles.map((file) => File(file.path)).toList();
      });
    }
  }

  Future<void> _generateAndSaveStory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final storyIngredients = {
        'productName': widget.product.name,
        'category': widget.product.category,
        'artisanName': widget.product.artisanName,
        'inspiration': _inspirationController.text,
        'materialsOrigin': _materialsOriginController.text,
        'craftingProcess': _craftingProcessController.text,
      };

      // Call the new Gemini Service function
      final generatedData = await GeminiService.generateArtisanLegacyStory(
        storyIngredients,
        _processImages,
      );

      // Update the product in Firestore
      final productService = ProductService();
      await productService.updateProductFields(
        widget.product.id,
        {
          'artisanLegacyStory': generatedData['story'],
          'provenanceMapData': generatedData['mapData'],
          'storyIngredients': storyIngredients,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Artisan's Legacy story generated and saved!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error generating story: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        title: Text(
          'Create Artisan Legacy', 
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFF2C1810),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C1810),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell the Story of "${widget.product.name}"',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22, 
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Provide the ingredients for a captivating story. Our AI will weave them into a beautiful narrative for your customers.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildTextField(
                      _inspirationController, 
                      "Inspiration", 
                      "What inspired this piece? A memory, a place, a feeling?",
                      Icons.lightbulb_outline,
                    ),
                    
                    _buildTextField(
                      _materialsOriginController, 
                      "Origin of Materials",
                      "Where do your materials come from? (e.g., 'Clay from the river near my village')",
                      Icons.nature_outlined,
                    ),
                    
                    _buildTextField(
                      _craftingProcessController, 
                      "Crafting Process",
                      "Briefly describe a unique step in your process.",
                      Icons.handyman_outlined,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      "Process Images (Optional, max 3)",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Select Images"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B6914),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    
                    if (_processImages.isNotEmpty) _buildImagePreview(),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateAndSaveStory,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isLoading ? "Generating Story..." : "Generate & Save Story",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C1810),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF8B6914)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2C1810), width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          labelStyle: TextStyle(color: Colors.grey.shade700),
        ),
        maxLines: 3,
        validator: (value) =>
            value == null || value.isEmpty ? 'This field cannot be empty' : null,
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selected Images:",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2C1810),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _processImages.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _processImages.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
