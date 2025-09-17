import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
              // Project Title
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
                              'Total Budget *', Icons.account_balance_wallet),
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
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDeadline != null
                                        ? '${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}'
                                        : 'Select Deadline',
                                    style: TextStyle(
                                      color: _selectedDeadline != null
                                          ? const Color(0xFF2C1810)
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
                        setState(() => _selectedStatus = value);
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
                          'Current Team Members',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2C1810),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddMemberDialog,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Add Member'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text('No team roles defined yet'),
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
      // Prepare updated data
      final updatedData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'totalBudget': double.parse(_budgetController.text.trim()),
        'deadline': Timestamp.fromDate(_selectedDeadline!),
        'status': _selectedStatus,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project updated successfully!'),
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
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Budget'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manage_members',
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 18),
                        SizedBox(width: 8),
                        Text('Manage Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove_role',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
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
                      'Budget Allocated',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '₹${role.allocatedBudget.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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
                      'Members',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${role.assignedArtisanIds.length}/${role.maxArtisans}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
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
                      'Status',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            _getRoleStatusColor(role.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getRoleStatusColor(role.status),
                        ),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFD4AF37),
                          child: Text(
                            memberInfo?['name']
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'M',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            memberInfo?['name'] ?? 'Loading...',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _removeMemberFromRole(role, memberId),
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 20),
                          tooltip: 'Remove member',
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

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddMemberDialog(
        existingRoles: _updatedRoles,
        onRoleAdded: (role) {
          setState(() {
            _updatedRoles.add(role);
          });
        },
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
                    status: updatedAssignedIds.length <
                            _updatedRoles[index].maxArtisans
                        ? 'open'
                        : 'filled',
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

  Color _getRoleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'filled':
        return Colors.green;
      case 'closed':
        return Colors.red;
      default:
        return Colors.grey;
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Delete the entire collaboration project\n'
                    '• Remove all team members\n'
                    '• Cancel all pending applications\n'
                    '• Notify all participants\n'
                    '• This action cannot be undone',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.red.shade700,
                      height: 1.4,
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

// Add this as a separate widget at the end of the edit_project_screen.dart file:

class _AddMemberDialog extends StatefulWidget {
  final List<CollaborationRole> existingRoles;
  final Function(CollaborationRole) onRoleAdded;

  const _AddMemberDialog({
    required this.existingRoles,
    required this.onRoleAdded,
  });

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _maxArtisansController = TextEditingController(text: '1');

  String _selectedDomain = 'Design';
  List<String> _selectedSkills = [];

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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Role'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Role Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a role title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Role Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Budget',
                          prefixText: '₹',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter budget';
                          }
                          final budget = double.tryParse(value);
                          if (budget == null || budget <= 0) {
                            return 'Invalid budget';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxArtisansController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Members',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter max members';
                          }
                          final max = int.tryParse(value);
                          if (max == null || max <= 0) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDomain,
                  decoration: const InputDecoration(
                    labelText: 'Domain',
                    border: OutlineInputBorder(),
                  ),
                  items: _domains
                      .map((domain) => DropdownMenuItem(
                            value: domain,
                            child: Text(domain),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedDomain = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Required Skills:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableSkills.map((skill) {
                    final isSelected = _selectedSkills.contains(skill);
                    return FilterChip(
                      label: Text(skill),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSkills.add(skill);
                          } else {
                            _selectedSkills.remove(skill);
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addRole,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add Role'),
        ),
      ],
    );
  }

  void _addRole() {
    if (_formKey.currentState!.validate()) {
      final role = CollaborationRole(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        domain: _selectedDomain,
        allocatedBudget: double.parse(_budgetController.text.trim()),
        maxArtisans: int.parse(_maxArtisansController.text.trim()),
        requiredSkills: _selectedSkills,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.onRoleAdded(role);
      Navigator.of(context).pop();
    }
  }
}

// Add this widget at the end of edit_project_screen.dart:

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
                        final searchTerm = _searchController.text.toLowerCase();

                        if (searchTerm.isNotEmpty &&
                            !artisan['name']
                                .toLowerCase()
                                .contains(searchTerm)) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFD4AF37),
                            child: Text(
                              artisan['name'].substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(artisan['name']),
                          subtitle: Text(artisan['specialty']),
                          trailing: Switch(
                            value: isAssigned,
                            onChanged: _assignedMembers.length >=
                                        widget.role.maxArtisans &&
                                    !isAssigned
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value) {
                                        if (_assignedMembers.length <
                                            widget.role.maxArtisans) {
                                          _assignedMembers.add(artisan['id']);
                                        }
                                      } else {
                                        _assignedMembers.remove(artisan['id']);
                                      }
                                    });
                                  },
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
