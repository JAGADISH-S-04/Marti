import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/collab_service.dart';
import '../../models/collab_model.dart';

class CreateCollaborationScreen extends StatefulWidget {
  final Map<String, dynamic> craftRequest;

  const CreateCollaborationScreen({
    Key? key,
    required this.craftRequest,
  }) : super(key: key);

  @override
  State<CreateCollaborationScreen> createState() =>
      _CreateCollaborationScreenState();
}

class _CreateCollaborationScreenState extends State<CreateCollaborationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalBudgetController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  final CollaborationService _collaborationService = CollaborationService();
  late TabController _tabController;

  bool _isLoading = false;
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 30));
  String _selectedCategory = '';
  bool _isUrgent = false;
  bool _allowPartialDelivery = false;
  bool _requireQualitySamples = false;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  List<CollaborationRole> _roles = [];

  // Available categories and domains
  final List<String> _categories = [
    'Jewelry',
    'Textiles',
    'Pottery',
    'Woodwork',
    'Metalwork',
    'Leatherwork',
    'Glasswork',
    'Paintings',
    'Sculptures',
    'Other'
  ];

  final List<String> _domains = [
    'Design',
    'Manufacturing',
    'Quality Control',
    'Packaging',
    'Marketing',
    'Photography',
    'Logistics',
    'Research'
  ];

  final List<String> _availableSkills = [
    'Hand Crafting',
    'Machine Operation',
    'Design',
    'Quality Control',
    'Packaging',
    'Marketing',
    'Photography',
    'Customer Service',
    'Logistics',
    'Research',
    'Traditional Techniques',
    'Modern Tools'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeFromCraftRequest();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _totalBudgetController.dispose();
    _additionalNotesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _initializeFromCraftRequest() {
    final request = widget.craftRequest;
    _titleController.text = request['title'] ?? '';
    _descriptionController.text = request['description'] ?? '';
    _totalBudgetController.text = (request['budget'] ?? 0).toString();
    _selectedCategory = request['category'] ?? _categories.first;

    // Set deadline based on craft request or default
    if (request['deadline'] != null) {
      try {
        _selectedDeadline = DateTime.parse(request['deadline'].toString());
      } catch (e) {
        _selectedDeadline = DateTime.now().add(const Duration(days: 30));
      }
    }

    // Initialize with a default role
    _addDefaultRole();
  }

  void _addDefaultRole() {
    final totalBudget = double.tryParse(_totalBudgetController.text) ?? 10000;
    final defaultRole = CollaborationRole(
      id: const Uuid().v4(),
      title: 'Lead Artisan',
      description: 'Primary craftsperson responsible for main production',
      domain: 'Manufacturing',
      allocatedBudget: totalBudget * 0.6,
      maxArtisans: 1,
      requiredSkills: ['Hand Crafting'],
      status: 'open', // Make sure this is 'open'
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _roles = [defaultRole];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Create Collaboration',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2C1810),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(text: 'Project Info', icon: Icon(Icons.info_outline)),
            Tab(text: 'Roles', icon: Icon(Icons.people_outline)),
            Tab(text: 'Settings', icon: Icon(Icons.settings_outlined)),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProjectInfoTab(),
            _buildRolesTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2C1810),
                  side: const BorderSide(color: Color(0xFF2C1810)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCollaboration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Creating...'),
                        ],
                      )
                    : const Text('Create Collaboration'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Title
          Text(
            'Project Title *',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter a descriptive project title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a project title';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Project Description
          Text(
            'Project Description *',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe what needs to be created, quality expectations, and any specific requirements',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Provide detailed project description...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a project description';
              }
              if (value.trim().length < 50) {
                return 'Description should be at least 50 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Category and Budget Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category *',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory.isNotEmpty
                          ? _selectedCategory
                          : null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? _categories.first;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Budget *',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _totalBudgetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixText: '₹',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter total budget';
                        }
                        final budget = double.tryParse(value);
                        if (budget == null || budget <= 0) {
                          return 'Please enter a valid budget';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Update role budgets when total budget changes
                        _updateRoleBudgets();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Deadline
          Text(
            'Project Deadline *',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDeadline,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedDeadline.day}/${_selectedDeadline.month}/${_selectedDeadline.year}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tags
          Text(
            'Project Tags',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add tags to help artisans find your project',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: 'Enter a tag',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onFieldSubmitted: _addTag,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _addTag(_tagController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map((tag) => Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                      deleteIconColor: const Color(0xFF2C1810),
                    ))
                .toList(),
          ),

          const SizedBox(height: 20),

          // Additional Notes
          Text(
            'Additional Notes',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _additionalNotesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Any additional information or special requirements...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesTab() {
    return Column(
      children: [
        // Header with Add Role button
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collaboration Roles',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    Text(
                      'Define roles and responsibilities for this project',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addNewRole,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Role'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Roles List
        Expanded(
          child: _roles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Roles Defined',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add roles to define collaboration structure',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    return _buildRoleCard(_roles[index], index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Settings',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 20),

          // Priority Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priority & Urgency',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Mark as Urgent'),
                  subtitle: const Text(
                      'Prioritize this project for faster applications'),
                  value: _isUrgent,
                  onChanged: (value) {
                    setState(() {
                      _isUrgent = value;
                    });
                  },
                  activeColor: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Delivery Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Options',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Allow Partial Delivery'),
                  subtitle: const Text(
                      'Artisans can deliver parts of the project separately'),
                  value: _allowPartialDelivery,
                  onChanged: (value) {
                    setState(() {
                      _allowPartialDelivery = value;
                    });
                  },
                  activeColor: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quality Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quality Assurance',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Require Quality Samples'),
                  subtitle: const Text(
                      'Artisans must provide samples before full production'),
                  value: _requireQualitySamples,
                  onChanged: (value) {
                    setState(() {
                      _requireQualitySamples = value;
                    });
                  },
                  activeColor: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Project Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: const Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Project Summary',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryItem('Total Roles', '${_roles.length}'),
                _buildSummaryItem(
                    'Total Budget', '₹${_totalBudgetController.text}'),
                _buildSummaryItem('Category', _selectedCategory),
                _buildSummaryItem('Deadline',
                    '${_selectedDeadline.day}/${_selectedDeadline.month}/${_selectedDeadline.year}'),
                if (_tags.isNotEmpty)
                  _buildSummaryItem('Tags', _tags.join(', ')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(CollaborationRole role, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  role.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editRole(index);
                  } else if (value == 'delete') {
                    _deleteRole(index);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            role.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRoleInfo(
                    'Budget', '₹${role.allocatedBudget.toStringAsFixed(0)}'),
              ),
              Expanded(
                child: _buildRoleInfo('Domain', role.domain),
              ),
              Expanded(
                child: _buildRoleInfo('Max Artisans', '${role.maxArtisans}'),
              ),
            ],
          ),
          if (role.requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Required Skills:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: role.requiredSkills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2C1810),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF2C1810),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C1810),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim());
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _addNewRole() {
    _showRoleDialog();
  }

  void _editRole(int index) {
    _showRoleDialog(role: _roles[index], index: index);
  }

  void _deleteRole(int index) {
    if (_roles.length > 1) {
      setState(() {
        _roles.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one role is required'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showRoleDialog({CollaborationRole? role, int? index}) {
    final titleController = TextEditingController(text: role?.title ?? '');
    final descriptionController =
        TextEditingController(text: role?.description ?? '');
    final budgetController =
        TextEditingController(text: role?.allocatedBudget.toString() ?? '');
    final maxArtisansController =
        TextEditingController(text: role?.maxArtisans.toString() ?? '1');
    String selectedDomain = role?.domain ?? _domains.first;
    List<String> selectedSkills = List.from(role?.requiredSkills ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(role == null ? 'Add New Role' : 'Edit Role'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role Title
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Role Title',
                      hintText: 'e.g., Lead Designer, Quality Controller',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role Description
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Role Description',
                      hintText: 'Describe responsibilities and expectations',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Domain
                  DropdownButtonFormField<String>(
                    value: selectedDomain,
                    decoration: const InputDecoration(labelText: 'Domain'),
                    items: _domains
                        .map((domain) => DropdownMenuItem(
                              value: domain,
                              child: Text(domain),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedDomain = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Budget and Max Artisans
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: budgetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Budget',
                            prefixText: '₹',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: maxArtisansController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Artisans',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Required Skills
                  const Text('Required Skills:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availableSkills.map((skill) {
                      final isSelected = selectedSkills.contains(skill);
                      return FilterChip(
                        label: Text(skill),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedSkills.add(skill);
                            } else {
                              selectedSkills.remove(skill);
                            }
                          });
                        },
                        selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty &&
                    descriptionController.text.trim().isNotEmpty &&
                    budgetController.text.trim().isNotEmpty) {
                  final newRole = CollaborationRole(
                    id: role?.id ?? const Uuid().v4(),
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    domain: selectedDomain,
                    allocatedBudget:
                        double.tryParse(budgetController.text) ?? 0,
                    maxArtisans: int.tryParse(maxArtisansController.text) ?? 1,
                    requiredSkills: selectedSkills,
                    createdAt: role?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  this.setState(() {
                    if (index != null) {
                      _roles[index] = newRole;
                    } else {
                      _roles.add(newRole);
                    }
                  });

                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
              ),
              child: Text(role == null ? 'Add Role' : 'Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateRoleBudgets() {
    final totalBudget = double.tryParse(_totalBudgetController.text) ?? 0;
    if (totalBudget > 0 && _roles.isNotEmpty) {
      final budgetPerRole = totalBudget / _roles.length;
      setState(() {
        for (int i = 0; i < _roles.length; i++) {
          _roles[i] = _roles[i].copyWith(allocatedBudget: budgetPerRole);
        }
      });
    }
  }

  Map<String, double> _calculateBudgetAllocation() {
    Map<String, double> allocation = {};

    for (final role in _roles) {
      allocation[role.title] = role.allocatedBudget;
    }

    return allocation;
  }

  Future<void> _createCollaboration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one role'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final collaborationRequest = CollaborationRequest(
        id: '', // Will be set by Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        totalBudget: double.parse(_totalBudgetController.text.trim()),
        deadline: _selectedDeadline,
        buyerId: widget.craftRequest['userId'] ??
            widget.craftRequest['buyerId'] ??
            user.uid,
        leadArtisanId: user.uid,
        collaboratorIds: [],
        requiredRoles: _roles,
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        originalRequestId: widget.craftRequest['id'],
        tags: _tags,
        isUrgent: _isUrgent,
        allowPartialDelivery: _allowPartialDelivery,
        requireQualitySamples: _requireQualitySamples,
        additionalNotes: _additionalNotesController.text.trim(),
        budgetAllocation: _calculateBudgetAllocation(),
        complexity: 'Standard',
      );

      final collaborationId = await _collaborationService
          .createCollaborationRequest(collaborationRequest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Collaboration project created successfully! Other artisans can now discover and join your project.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating collaboration: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
