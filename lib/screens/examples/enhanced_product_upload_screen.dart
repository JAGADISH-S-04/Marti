import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/product_database_service.dart';
import '../../services/firebase_storage_service.dart';

class EnhancedProductUploadScreen extends StatefulWidget {
  const EnhancedProductUploadScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedProductUploadScreen> createState() => _EnhancedProductUploadScreenState();
}

class _EnhancedProductUploadScreenState extends State<EnhancedProductUploadScreen> {
  final ProductDatabaseService _productService = ProductDatabaseService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final ImagePicker _picker = ImagePicker();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _craftingTimeController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _stockController = TextEditingController();
  final _careInstructionsController = TextEditingController();
  final _sellerNameController = TextEditingController();
  
  // Selected values
  String _selectedCategory = 'Home Decor';
  List<String> _materials = [];
  List<String> _tags = [];
  
  // Files
  File? _mainImage;
  List<File> _additionalImages = [];
  File? _videoFile;
  
  bool _isUploading = false;
  
  final List<String> _categories = [
    'Home Decor',
    'Jewelry',
    'Clothing',
    'Art',
    'Furniture',
    'Pottery',
    'Textiles',
    'Woodwork',
    'Metalwork',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: Colors.brown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            _buildSectionHeader('Basic Information'),
            _buildTextField(_nameController, 'Product Name', required: true),
            _buildTextField(_descriptionController, 'Description', maxLines: 3, required: true),
            _buildTextField(_sellerNameController, 'Seller/Business Name', required: true),
            
            const SizedBox(height: 16),
            
            // Category and Price Section
            _buildSectionHeader('Category & Pricing'),
            _buildCategoryDropdown(),
            _buildTextField(_priceController, 'Price (\$)', keyboardType: TextInputType.number, required: true),
            
            const SizedBox(height: 16),
            
            // Product Details Section
            _buildSectionHeader('Product Details'),
            _buildTextField(_craftingTimeController, 'Crafting Time', required: true),
            _buildTextField(_dimensionsController, 'Dimensions', required: true),
            _buildTextField(_stockController, 'Stock Quantity', keyboardType: TextInputType.number, required: true),
            _buildTextField(_careInstructionsController, 'Care Instructions', maxLines: 2),
            
            const SizedBox(height: 16),
            
            // Materials Section
            _buildSectionHeader('Materials'),
            _buildMaterialsInput(),
            
            const SizedBox(height: 16),
            
            // Tags Section
            _buildSectionHeader('Tags'),
            _buildTagsInput(),
            
            const SizedBox(height: 16),
            
            // Images Section
            _buildSectionHeader('Images'),
            _buildImageUploadSection(),
            
            const SizedBox(height: 16),
            
            // Video Section (Optional)
            _buildSectionHeader('Video (Optional)'),
            _buildVideoUploadSection(),
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Product', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.brown,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.brown),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        decoration: InputDecoration(
          labelText: 'Category *',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategory = value!;
          });
        },
      ),
    );
  }

  Widget _buildMaterialsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: _materials.map((material) {
            return Chip(
              label: Text(material),
              onDeleted: () {
                setState(() {
                  _materials.remove(material);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Add Material',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddDialog('Material', _materials),
            ),
          ),
          onFieldSubmitted: (value) {
            if (value.isNotEmpty && !_materials.contains(value)) {
              setState(() {
                _materials.add(value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: _tags.map((tag) {
            return Chip(
              label: Text(tag),
              onDeleted: () {
                setState(() {
                  _tags.remove(tag);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Add Tag',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddDialog('Tag', _tags),
            ),
          ),
          onFieldSubmitted: (value) {
            if (value.isNotEmpty && !_tags.contains(value)) {
              setState(() {
                _tags.add(value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Image
        const Text('Main Display Image *', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _mainImage != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _mainImage!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => setState(() => _mainImage = null),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: _pickMainImage,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                      Text('Tap to add main image'),
                    ],
                  ),
                ),
        ),
        
        const SizedBox(height: 16),
        
        // Additional Images
        const Text('Additional Images', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _additionalImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _additionalImages.length) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: _pickAdditionalImages,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 30, color: Colors.grey),
                        Text('Add', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }
              
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _additionalImages[index],
                        width: 100,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        onPressed: () => setState(() => _additionalImages.removeAt(index)),
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(24, 24),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _videoFile != null
              ? Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_file, size: 40, color: Colors.brown),
                          Text(
                            _videoFile!.path.split('/').last,
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => setState(() => _videoFile = null),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: _pickVideo,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_call, size: 40, color: Colors.grey),
                      Text('Tap to add video'),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddDialog(String type, List<String> list) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $type'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Enter $type',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty && !list.contains(controller.text)) {
                setState(() {
                  list.add(controller.text);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMainImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _mainImage = File(image.path);
      });
    }
  }

  Future<void> _pickAdditionalImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    for (XFile image in images) {
      if (_additionalImages.length < 5) { // Limit to 5 additional images
        setState(() {
          _additionalImages.add(File(image.path));
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
      });
    }
  }

  Future<void> _submitProduct() async {
    // Validate required fields
    if (_nameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _sellerNameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _craftingTimeController.text.isEmpty ||
        _dimensionsController.text.isEmpty ||
        _stockController.text.isEmpty ||
        _mainImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields and add a main image')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Create product using the new organized storage service
      final productId = await _productService.createProduct(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        materials: _materials,
        craftingTime: _craftingTimeController.text,
        dimensions: _dimensionsController.text,
        mainImage: _mainImage!,
        additionalImages: _additionalImages,
        sellerName: _sellerNameController.text,
        stockQuantity: int.parse(_stockController.text),
        tags: _tags,
        video: _videoFile,
        careInstructions: _careInstructionsController.text.isEmpty 
            ? null : _careInstructionsController.text,
      );

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product created successfully! ID: $productId')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating product: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _craftingTimeController.dispose();
    _dimensionsController.dispose();
    _stockController.dispose();
    _careInstructionsController.dispose();
    _sellerNameController.dispose();
    super.dispose();
  }
}
