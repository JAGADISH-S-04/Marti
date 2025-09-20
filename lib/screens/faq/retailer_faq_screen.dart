import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/faq.dart';
import '../../services/faq_service.dart';
import '../../widgets/faq/faq_search_widget.dart';
import '../../widgets/faq/faq_category_filter_widget.dart';
import '../../widgets/faq/simple_faq_item_widget.dart';

class RetailerFAQScreen extends StatefulWidget {
  final FAQCategory? initialCategory;
  final String? initialSearchQuery;

  const RetailerFAQScreen({
    Key? key,
    this.initialCategory,
    this.initialSearchQuery,
  }) : super(key: key);

  @override
  State<RetailerFAQScreen> createState() => _RetailerFAQScreenState();
}

class _RetailerFAQScreenState extends State<RetailerFAQScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FAQCategory? _selectedCategory;
  String _searchQuery = '';
  List<FAQ> _faqs = [];
  List<FAQ> _frequentlyAsked = [];
  bool _isLoading = true;
  bool _isSearching = false;

  final Color primaryColor = const Color.fromARGB(255, 93, 64, 55);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedCategory = widget.initialCategory;
    _searchQuery = widget.initialSearchQuery ?? '';
    _loadFAQs();
    _loadFrequentlyAskedQuestions();
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
      // Initialize default FAQs if needed
      await FAQService.initializeDefaultFAQs();
    } catch (e) {
      print('Error initializing FAQs: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFrequentlyAskedQuestions() async {
    try {
      // Listen to frequently asked questions stream for retailers only
      FAQService.getFrequentlyAskedQuestions(
        userType: UserType.retailer,
        limit: 5,
      ).listen((faqs) {
        if (mounted) {
          setState(() {
            _frequentlyAsked = faqs;
          });
        }
      });
    } catch (e) {
      print('Error loading frequently asked questions: $e');
    }
  }

  List<FAQCategory> _getRetailerCategories() {
    return [
      FAQCategory.account,
      FAQCategory.products,
      FAQCategory.orders,
      FAQCategory.inventory,
      FAQCategory.commissions,
      FAQCategory.analytics,
      FAQCategory.verification,
      FAQCategory.communication,
      FAQCategory.onboarding,
      FAQCategory.technical,
      FAQCategory.general,
    ];
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });
  }

  void _onCategoryChanged(FAQCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  Stream<List<FAQ>> _getFAQsStream() {
    return FAQService.getFAQsStream(
      userType: UserType.retailer,
      category: _selectedCategory,
      searchQuery: _isSearching ? _searchQuery : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Retailer Help Center',
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
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.list), text: 'Browse'),
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
                _buildSearchTab(),
                _buildBrowseTab(),
              ],
            ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              FAQSearchWidget(
                initialQuery: _searchQuery,
                onSearchChanged: _onSearchChanged,
                hintText: 'Search retailer support topics...',
              ),
              const SizedBox(height: 16),
              FAQCategoryFilterWidget(
                categories: _getRetailerCategories(),
                selectedCategory: _selectedCategory,
                onCategorySelected: _onCategoryChanged,
                userType: UserType.retailer,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FAQ>>(
            stream: _getFAQsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading FAQs',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again later',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final faqs = snapshot.data ?? [];

              if (faqs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSearching ? Icons.search_off : Icons.help_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSearching ? 'No results found' : 'No FAQs available',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSearching
                            ? 'Try different keywords or browse categories'
                            : 'Check back later for help topics',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  return SimpleFAQItemWidget(faq: faqs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: FAQCategoryFilterWidget(
            categories: _getRetailerCategories(),
            selectedCategory: _selectedCategory,
            onCategorySelected: _onCategoryChanged,
            userType: UserType.retailer,
          ),
        ),
        if (_frequentlyAsked.isNotEmpty) ...[
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frequently Asked Questions',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _frequentlyAsked.length,
                    itemBuilder: (context, index) {
                      final faq = _frequentlyAsked[index];
                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              faq.question,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              faq.answer,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: StreamBuilder<List<FAQ>>(
            stream: FAQService.getFAQsStream(
              userType: UserType.retailer,
              category: _selectedCategory,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading FAQs',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final faqs = snapshot.data ?? [];

              if (faqs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.help_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No FAQs available',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later for help topics',
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
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  return SimpleFAQItemWidget(faq: faqs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
