import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQSearchWidget extends StatefulWidget {
  final Function(String) onSearchChanged;
  final VoidCallback? onClearSearch;
  final String? initialQuery;
  final String hintText;

  const FAQSearchWidget({
    Key? key,
    required this.onSearchChanged,
    this.onClearSearch,
    this.initialQuery,
    this.hintText = 'Search frequently asked questions...',
  }) : super(key: key);

  @override
  State<FAQSearchWidget> createState() => _FAQSearchWidgetState();
}

class _FAQSearchWidgetState extends State<FAQSearchWidget> {
  late TextEditingController _searchController;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _hasText = widget.initialQuery?.isNotEmpty ?? false;
    _searchController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onSearchChanged(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onClearSearch?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.grey[800],
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.grey[500],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: 22,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  onPressed: _clearSearch,
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onSubmitted: (value) {
          // Optional: Handle search submission
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
