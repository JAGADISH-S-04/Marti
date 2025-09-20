import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/faq.dart';
import '../../services/faq_service.dart';
import '../../services/admin_service.dart';

class FAQManagementScreen extends StatefulWidget {
  const FAQManagementScreen({Key? key}) : super(key: key);

  @override
  State<FAQManagementScreen> createState() => _FAQManagementScreenState();
}

class _FAQManagementScreenState extends State<FAQManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FAQ> _customerFAQs = [];
  List<FAQ> _retailerFAQs = [];
  bool _isLoading = true;

  final Color primaryColor = const Color.fromARGB(255, 93, 64, 55);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    if (!await AdminService.hasAdminAccess('faq_management')) {
      if (mounted) {
        AdminService.showAdminAccessDeniedDialog(context);
        Navigator.pop(context);
      }
      return;
    }
    _loadFAQs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFAQs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load customer FAQs
      FAQService.getFAQsStream(userType: UserType.customer).listen((faqs) {
        if (mounted) {
          setState(() {
            _customerFAQs = faqs;
          });
        }
      });

      // Load retailer FAQs
      FAQService.getFAQsStream(userType: UserType.retailer).listen((faqs) {
        if (mounted) {
          setState(() {
            _retailerFAQs = faqs;
          });
        }
      });
    } catch (e) {
      print('Error loading FAQs: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'FAQ Management',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Customer FAQs'),
            Tab(icon: Icon(Icons.store), text: 'Retailer FAQs'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildFAQListTab(UserType.customer, _customerFAQs),
                _buildFAQListTab(UserType.retailer, _retailerFAQs),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFAQDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add FAQ'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Customer FAQs',
                  _customerFAQs.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Retailer FAQs',
                  _retailerFAQs.length.toString(),
                  Icons.store,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Initialize Sample Data',
            'Add default FAQs to get started',
            Icons.rocket_launch,
            Colors.green,
            () => _initializeSampleData(),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Export FAQs',
            'Download FAQ data as CSV',
            Icons.download,
            Colors.purple,
            () => _exportFAQs(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQListTab(UserType userType, List<FAQ> faqs) {
    if (faqs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No FAQs yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first FAQ to get started',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final faq = faqs[index];
        return _buildFAQCard(faq);
      },
    );
  }

  Widget _buildFAQCard(FAQ faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          faq.category.displayName,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: primaryColor,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditFAQDialog(faq),
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _deleteFAQ(faq),
              color: Colors.red,
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Answer:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  faq.answer,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (faq.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: faq.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: primaryColor.withOpacity(0.1),
                              labelStyle: TextStyle(
                                color: primaryColor,
                                fontSize: 12,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFAQDialog() {
    showDialog(
      context: context,
      builder: (context) => FAQFormDialog(
        onSave: (faq) async {
          await FAQService.createFAQ(faq);
          _loadFAQs();
        },
      ),
    );
  }

  void _showEditFAQDialog(FAQ faq) {
    showDialog(
      context: context,
      builder: (context) => FAQFormDialog(
        faq: faq,
        onSave: (updatedFAQ) async {
          await FAQService.updateFAQ(updatedFAQ);
          _loadFAQs();
        },
      ),
    );
  }

  Future<void> _deleteFAQ(FAQ faq) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete FAQ'),
        content: Text('Are you sure you want to delete "${faq.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FAQService.deleteFAQ(faq.id);
      _loadFAQs();
    }
  }

  Future<void> _initializeSampleData() async {
    try {
      await FAQService.initializeDefaultFAQs();
      _loadFAQs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample FAQs initialized successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing FAQs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportFAQs() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
      ),
    );
  }
}

class FAQFormDialog extends StatefulWidget {
  final FAQ? faq;
  final Function(FAQ) onSave;

  const FAQFormDialog({
    Key? key,
    this.faq,
    required this.onSave,
  }) : super(key: key);

  @override
  State<FAQFormDialog> createState() => _FAQFormDialogState();
}

class _FAQFormDialogState extends State<FAQFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _questionController;
  late TextEditingController _answerController;
  late TextEditingController _tagsController;
  FAQCategory _selectedCategory = FAQCategory.general;
  UserType _selectedUserType = UserType.customer;
  int _priority = 1;

  @override
  void initState() {
    super.initState();
    _questionController =
        TextEditingController(text: widget.faq?.question ?? '');
    _answerController = TextEditingController(text: widget.faq?.answer ?? '');
    _tagsController = TextEditingController(
      text: widget.faq?.tags.join(', ') ?? '',
    );
    if (widget.faq != null) {
      _selectedCategory = widget.faq!.category;
      _selectedUserType = widget.faq!.targetUserType;
      _priority = widget.faq!.priority;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.faq == null ? 'Add New FAQ' : 'Edit FAQ',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _answerController,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter an answer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FAQCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: FAQCategory.values
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.displayName),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<UserType>(
                      value: _selectedUserType,
                      decoration: const InputDecoration(
                        labelText: 'User Type',
                        border: OutlineInputBorder(),
                      ),
                      items: UserType.values
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.name.toUpperCase()),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUserType = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _priority.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _priority = int.tryParse(value) ?? 1;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveFAQ,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 93, 64, 55),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveFAQ() {
    if (_formKey.currentState?.validate() ?? false) {
      final now = DateTime.now();
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final faq = FAQ(
        id: widget.faq?.id ?? '',
        question: _questionController.text.trim(),
        answer: _answerController.text.trim(),
        category: _selectedCategory,
        targetUserType: _selectedUserType,
        tags: tags,
        priority: _priority,
        createdAt: widget.faq?.createdAt ?? now,
        updatedAt: now,
        analytics: widget.faq?.analytics ??
            {'viewCount': 0, 'helpfulCount': 0, 'notHelpfulCount': 0},
      );

      widget.onSave(faq);
      Navigator.pop(context);
    }
  }
}
