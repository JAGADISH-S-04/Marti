import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/collab_model.dart';
import '../../services/collab_service.dart';

class EditProjectScreen extends StatefulWidget {
  final CollaborationRequest collaboration;

  const EditProjectScreen({
    Key? key,
    required this.collaboration,
  }) : super(key: key);

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final CollaborationService _collaborationService = CollaborationService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;
  late TextEditingController _notesController;

  DateTime? _selectedDeadline;
  String _selectedStatus = 'open';
  bool _isUrgent = false;
  bool _allowPartialDelivery = false;
  bool _requireQualitySamples = false;
  bool _isSubmitting = false;

  final List<String> _statusOptions = [
    'open',
    'in_progress',
    'completed',
    'cancelled'
  ];

  List<CollaborationRole> _updatedRoles = [];

  // Available domains and skills for new roles
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
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.collaboration.title);
    _descriptionController =
        TextEditingController(text: widget.collaboration.description);
    _budgetController = TextEditingController(
        text: widget.collaboration.totalBudget.toString());
    _notesController =
        TextEditingController(text: widget.collaboration.additionalNotes ?? '');

    _selectedDeadline = widget.collaboration.deadline;
    _selectedStatus = widget.collaboration.status;
    _isUrgent = widget.collaboration.isUrgent ?? false;
    _allowPartialDelivery = widget.collaboration.allowPartialDelivery ?? false;
    _requireQualitySamples =
        widget.collaboration.requireQualitySamples ?? false;

    _updatedRoles =
        List<CollaborationRole>.from(widget.collaboration.requiredRoles);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Edit Project',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C1810),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C1810)),
        actions: [
          // Cancel Collaboration Button
          TextButton.icon(
            onPressed: _showCancelCollaborationDialog,
            icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
            label: const Text(
              'Cancel Project',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          // Save Button
          TextButton(
            onPressed: _isSubmitting ? null : _saveChanges,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: const Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Details
              _buildSectionCard(
                'Project Details',
                [
                  TextFormField(
                    controller: _titleController,
                    decoration:
                        _buildInputDecoration('Project Title *', Icons.title),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a project title';
                      }
                      if (value.trim().length < 5) {
                        return 'Title must be at least 5 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: _buildInputDecoration(
                        'Description *', Icons.description),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      if (value.trim().length < 20) {
                        return 'Description must be at least 20 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Budget and Timeline
              _buildSectionCard(
                'Budget & Timeline',
                [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                              'Total Budget *', Icons.currency_rupee),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter budget';
                            }
                            final budget = double.tryParse(value);
                            if (budget == null || budget <= 0) {
                              return 'Please enter valid budget';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _selectDeadline,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule,
                                    color: const Color(0xFFD4AF37)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedDeadline != null
                                        ? '${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}'
                                        : 'Select Deadline',
                                    style: TextStyle(
                                      color: _selectedDeadline != null
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Project Status
              _buildSectionCard(
                'Project Status',
                [
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: _buildInputDecoration('Status', Icons.flag),
                    items: _statusOptions
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusDisplayName(status)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Project Settings
              _buildSectionCard(
                'Project Settings',
                [
                  SwitchListTile(
                    title: const Text('Urgent Project'),
                    subtitle: const Text('Mark this project as high priority'),
                    value: _isUrgent,
                    onChanged: (value) => setState(() => _isUrgent = value),
                    activeColor: const Color(0xFFD4AF37),
                  ),
                  SwitchListTile(
                    title: const Text('Allow Partial Delivery'),
                    subtitle: const Text('Accept incomplete deliverables'),
                    value: _allowPartialDelivery,
                    onChanged: (value) =>
                        setState(() => _allowPartialDelivery = value),
                    activeColor: const Color(0xFFD4AF37),
                  ),
                  SwitchListTile(
                    title: const Text('Require Quality Samples'),
                    subtitle:
                        const Text('Request work samples from applicants'),
                    value: _requireQualitySamples,
                    onChanged: (value) =>
                        setState(() => _requireQualitySamples = value),
                    activeColor: const Color(0xFFD4AF37),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Team Management
              _buildSectionCard(
                'Team Management',
                [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Roles & Team Members (${_updatedRoles.length})',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C1810),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addNewRole,
                        icon: const Icon(Icons.add, size: 16),
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
                  const SizedBox(height: 16),

                  // Display current team members
                  ..._updatedRoles.map((role) => _buildRoleMemberCard(role)),

                  if (_updatedRoles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey.shade500),
                            const SizedBox(height: 12),
                            Text(
                              'No roles defined yet',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add roles to define your team structure',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Additional Notes
              _buildSectionCard(
                'Additional Notes',
                [
                  TextFormField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: _buildInputDecoration(
                        'Additional Notes (Optional)', Icons.note),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                  ),
                  child: _isSubmitting
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
                            Text('Saving Changes...'),
                          ],
                        )
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4AF37),
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _selectedDeadline = date);
    }
  }

  Widget _buildRoleMemberCard(CollaborationRole role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  role.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'edit_budget':
                      _showEditBudgetDialog(role);
                      break;
                    case 'manage_members':
                      _showManageMembersDialog(role);
                      break;
                    case 'remove_role':
                      _showRemoveRoleDialog(role);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit_budget',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Budget'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manage_members',
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 16),
                        SizedBox(width: 8),
                        Text('Manage Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove_role',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove Role',
                            style: TextStyle(color: Colors.red)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${role.allocatedBudget.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Domain',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      role.domain,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capacity',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${role.assignedArtisanIds.length}/${role.maxArtisans}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (role.assignedArtisanIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Assigned Members:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            ...role.assignedArtisanIds.map(
              (memberId) => FutureBuilder<Map<String, dynamic>?>(
                future: _getMemberInfo(memberId),
                builder: (context, snapshot) {
                  final memberInfo = snapshot.data;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFD4AF37),
                          child: Text(
                            (memberInfo?['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            memberInfo?['name'] ?? 'Unknown Member',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 16),
                          onPressed: () =>
                              _removeMemberFromRole(role, memberId),
                          tooltip: 'Remove Member',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addNewRole() {
    _showRoleDialog();
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
                      labelText: 'Description',
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
                    assignedArtisanIds: role?.assignedArtisanIds ?? [],
                    status: role?.status ?? 'open',
                    createdAt: role?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  this.setState(() {
                    if (index != null) {
                      _updatedRoles[index] = newRole;
                    } else {
                      _updatedRoles.add(newRole);
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

  void _showEditBudgetDialog(CollaborationRole role) {
    final budgetController = TextEditingController(
      text: role.allocatedBudget.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Budget for ${role.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Budget: ₹${role.allocatedBudget.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Budget Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newBudget = double.tryParse(budgetController.text);
              if (newBudget != null && newBudget > 0) {
                setState(() {
                  final index =
                      _updatedRoles.indexWhere((r) => r.id == role.id);
                  if (index != -1) {
                    _updatedRoles[index] = _updatedRoles[index].copyWith(
                      allocatedBudget: newBudget,
                      updatedAt: DateTime.now(),
                    );
                  }
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Budget updated successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showManageMembersDialog(CollaborationRole role) {
    showDialog(
      context: context,
      builder: (context) => _ManageMembersDialog(
        role: role,
        onMembersUpdated: (updatedRole) {
          setState(() {
            final index = _updatedRoles.indexWhere((r) => r.id == role.id);
            if (index != -1) {
              _updatedRoles[index] = updatedRole;
            }
          });

          // Check if all roles are filled and auto-update status
          bool allRolesFilled = _updatedRoles.isNotEmpty &&
              _updatedRoles.every((role) {
                return role.assignedArtisanIds.length >= role.maxArtisans;
              });

          if (_selectedStatus == 'open' && allRolesFilled) {
            setState(() {
              _selectedStatus = 'in_progress';
            });

            // Show notification to user about auto status change
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                          'All roles filled! Status automatically changed to "In Progress"'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }

  void _showRemoveRoleDialog(CollaborationRole role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Role'),
        content: Text(
          'Are you sure you want to remove the "${role.title}" role from this project?\n\n'
          'This will remove all assigned members from this role.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _updatedRoles.removeWhere((r) => r.id == role.id);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${role.title} role removed')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _removeMemberFromRole(CollaborationRole role, String memberId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text(
            'Are you sure you want to remove this member from the role?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = _updatedRoles.indexWhere((r) => r.id == role.id);
                if (index != -1) {
                  final updatedAssignedIds = List<String>.from(
                      _updatedRoles[index].assignedArtisanIds);
                  updatedAssignedIds.remove(memberId);

                  _updatedRoles[index] = _updatedRoles[index].copyWith(
                    assignedArtisanIds: updatedAssignedIds,
                    status: updatedAssignedIds.length >= role.maxArtisans
                        ? 'filled'
                        : 'open',
                    updatedAt: DateTime.now(),
                  );
                }
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Member removed successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getMemberInfo(String memberId) async {
    try {
      // Try retailers collection first
      var doc = await FirebaseFirestore.instance
          .collection('retailers')
          .doc(memberId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['fullName'] ?? data['name'] ?? 'Unknown Member',
          'email': data['email'] ?? '',
        };
      }

      // Try users collection
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? data['displayName'] ?? 'Unknown Member',
          'email': data['email'] ?? '',
        };
      }

      return {'name': 'Unknown Member', 'email': ''};
    } catch (e) {
      print('Error getting member info: $e');
      return {'name': 'Unknown Member', 'email': ''};
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a deadline'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Check if all roles are filled and auto-update status
      bool allRolesFilled = _updatedRoles.isNotEmpty &&
          _updatedRoles.every((role) {
            return role.assignedArtisanIds.length >= role.maxArtisans;
          });

      // Auto-update status logic
      String finalStatus = _selectedStatus;
      if (_selectedStatus == 'open' && allRolesFilled) {
        finalStatus = 'in_progress';

        // Show notification to user about auto status change
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                        'All roles filled! Status automatically changed to "In Progress"'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Prepare updated data
      final updatedData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'totalBudget': double.parse(_budgetController.text.trim()),
        'deadline': Timestamp.fromDate(_selectedDeadline!),
        'status': finalStatus, // Use the potentially auto-updated status
        'isUrgent': _isUrgent,
        'allowPartialDelivery': _allowPartialDelivery,
        'requireQualitySamples': _requireQualitySamples,
        'additionalNotes': _notesController.text.trim(),
        'requiredRoles': _updatedRoles.map((role) => role.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(widget.collaboration.id)
          .update(updatedData);

      // Update collaborator IDs based on roles
      final Set<String> allCollaborators = {};
      for (final role in _updatedRoles) {
        allCollaborators.addAll(role.assignedArtisanIds);
      }

      await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(widget.collaboration.id)
          .update({
        'collaboratorIds': allCollaborators.toList(),
      });

      // Create notifications for status change if auto-updated
      if (finalStatus != _selectedStatus && finalStatus == 'in_progress') {
        await _notifyStatusChange(allCollaborators.toList(), finalStatus);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  finalStatus != _selectedStatus
                      ? 'Project updated and status changed to In Progress!'
                      : 'Project updated successfully!',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Return to previous screen with success result
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating project: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Add method to notify team members about status changes
  Future<void> _notifyStatusChange(
      List<String> collaboratorIds, String newStatus) async {
    try {
      final notifications = <Future>[];

      // Notify all collaborators about status change
      for (final collaboratorId in collaboratorIds) {
        if (collaboratorId != FirebaseAuth.instance.currentUser?.uid) {
          notifications.add(
            FirebaseFirestore.instance.collection('notifications').add({
              'userId': collaboratorId,
              'title': 'Project Status Updated',
              'message':
                  'The project "${widget.collaboration.title}" status has been changed to "${_getStatusDisplayName(newStatus)}" because all roles are now filled!',
              'type': 'project_status_change',
              'data': {
                'projectId': widget.collaboration.id,
                'projectTitle': widget.collaboration.title,
                'newStatus': newStatus,
              },
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            }),
          );
        }
      }

      // Notify the buyer if different from lead artisan
      if (widget.collaboration.buyerId != null &&
          widget.collaboration.buyerId !=
              FirebaseAuth.instance.currentUser?.uid &&
          !collaboratorIds.contains(widget.collaboration.buyerId)) {
        notifications.add(
          FirebaseFirestore.instance.collection('notifications').add({
            'userId': widget.collaboration.buyerId,
            'title': 'Project Status Updated',
            'message':
                'Your project "${widget.collaboration.title}" is now in progress! All roles have been filled.',
            'type': 'project_status_change',
            'data': {
              'projectId': widget.collaboration.id,
              'projectTitle': widget.collaboration.title,
              'newStatus': newStatus,
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          }),
        );
      }

      await Future.wait(notifications);
    } catch (e) {
      print('Error sending status change notifications: $e');
    }
  }

  // Add cancel collaboration dialog method
  void _showCancelCollaborationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Cancel Collaboration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this collaboration project?',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C1810),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Delete the project permanently\n'
                    '• Remove all team members\n'
                    '• Cancel all pending applications\n'
                    '• This cannot be undone',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep Project',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelCollaboration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete Project',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Add cancel collaboration method
  Future<void> _cancelCollaboration() async {
    setState(() => _isSubmitting = true);

    try {
      // Create notifications for all team members before deletion
      final notifications = <Future>[];

      // Notify all collaborators
      for (final collaboratorId in widget.collaboration.collaboratorIds) {
        if (collaboratorId != FirebaseAuth.instance.currentUser?.uid) {
          notifications
              .add(FirebaseFirestore.instance.collection('notifications').add({
            'userId': collaboratorId,
            'title': 'Project Deleted',
            'message':
                'The collaboration project "${widget.collaboration.title}" has been cancelled and deleted by the project leader.',
            'type': 'project_deleted',
            'data': {
              'projectId': widget.collaboration.id,
              'projectTitle': widget.collaboration.title,
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          }));
        }
      }

      // Notify the buyer if different from lead artisan
      if (widget.collaboration.buyerId != null &&
          widget.collaboration.buyerId !=
              FirebaseAuth.instance.currentUser?.uid) {
        notifications
            .add(FirebaseFirestore.instance.collection('notifications').add({
          'userId': widget.collaboration.buyerId,
          'title': 'Project Deleted',
          'message':
              'Your collaboration project "${widget.collaboration.title}" has been cancelled and deleted.',
          'type': 'project_deleted',
          'data': {
            'projectId': widget.collaboration.id,
            'projectTitle': widget.collaboration.title,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        }));
      }

      // Wait for all notifications to be sent
      await Future.wait(notifications);

      // Delete all subcollections first
      final batch = FirebaseFirestore.instance.batch();

      // Delete applications
      final applicationsQuery = await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(widget.collaboration.id)
          .collection('applications')
          .get();

      for (final doc in applicationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete tasks
      final tasksQuery = await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(widget.collaboration.id)
          .collection('tasks')
          .get();

      for (final doc in tasksQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete messages
      final messagesQuery = await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(widget.collaboration.id)
          .collection('messages')
          .get();

      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit subcollection deletions
      await batch.commit();

      // Finally, delete the main project document
      await FirebaseFirestore.instance
          .collection('collaboration_projects')
          .doc(widget.collaboration.id)
          .delete();

      // Update the original craft request to remove collaboration flags
      if (widget.collaboration.originalRequestId != null) {
        await FirebaseFirestore.instance
            .collection('craft_requests')
            .doc(widget.collaboration.originalRequestId)
            .update({
          'isOpenForCollaboration': false,
          'collaborationProjectId': FieldValue.delete(),
          'collaborationStatus': FieldValue.delete(),
          'leadArtisanId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaboration project deleted successfully'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to previous screen
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting project: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// Add this as a separate widget at the end of the file:

class _ManageMembersDialog extends StatefulWidget {
  final CollaborationRole role;
  final Function(CollaborationRole) onMembersUpdated;

  const _ManageMembersDialog({
    required this.role,
    required this.onMembersUpdated,
  });

  @override
  State<_ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<_ManageMembersDialog> {
  late List<String> _assignedMembers;
  List<Map<String, dynamic>> _availableArtisans = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _assignedMembers = List.from(widget.role.assignedArtisanIds);
    _loadAvailableArtisans();
  }

  Future<void> _loadAvailableArtisans() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('retailers')
          .limit(50)
          .get();

      final artisans = query.docs
          .map((doc) => {
                'id': doc.id,
                'name':
                    doc.data()['fullName'] ?? doc.data()['name'] ?? 'Unknown',
                'email': doc.data()['email'] ?? '',
                'specialty': doc.data()['specialty'] ?? 'General',
              })
          .toList();

      setState(() {
        _availableArtisans = artisans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading artisans: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage Members - ${widget.role.title}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search artisans',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Current members count
            Text(
              'Members: ${_assignedMembers.length}/${widget.role.maxArtisans}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Available artisans list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _availableArtisans.length,
                      itemBuilder: (context, index) {
                        final artisan = _availableArtisans[index];
                        final isAssigned =
                            _assignedMembers.contains(artisan['id']);
                        final canAssign =
                            _assignedMembers.length < widget.role.maxArtisans ||
                                isAssigned;

                        // Filter based on search
                        if (_searchController.text.isNotEmpty &&
                            !artisan['name'].toString().toLowerCase().contains(
                                _searchController.text.toLowerCase())) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFD4AF37),
                            child: Text(
                              artisan['name'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(artisan['name']),
                          subtitle: Text(artisan['specialty']),
                          trailing: Checkbox(
                            value: isAssigned,
                            onChanged: canAssign
                                ? (value) {
                                    setState(() {
                                      if (value == true) {
                                        _assignedMembers.add(artisan['id']);
                                      } else {
                                        _assignedMembers.remove(artisan['id']);
                                      }
                                    });
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  void _saveChanges() {
    final updatedRole = widget.role.copyWith(
      assignedArtisanIds: _assignedMembers,
      status: _assignedMembers.length >= widget.role.maxArtisans
          ? 'filled'
          : 'open',
      updatedAt: DateTime.now(),
    );

    widget.onMembersUpdated(updatedRole);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Members updated successfully')),
    );
  }
}
