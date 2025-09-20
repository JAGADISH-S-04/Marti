import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/faq.dart';

class SimpleFAQItemWidget extends StatefulWidget {
  final FAQ faq;

  const SimpleFAQItemWidget({
    Key? key,
    required this.faq,
  }) : super(key: key);

  @override
  State<SimpleFAQItemWidget> createState() => _SimpleFAQItemWidgetState();
}

class _SimpleFAQItemWidgetState extends State<SimpleFAQItemWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color.fromARGB(255, 93, 64, 55);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          title: Text(
            widget.faq.question,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          subtitle: Text(
            widget.faq.category.displayName,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: primaryColor,
            ),
          ),
          trailing: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: primaryColor,
            size: 24,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
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
                    SizedBox(height: 8),
                    Text(
                      widget.faq.answer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    if (widget.faq.tags.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: widget.faq.tags
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor:
                                      primaryColor.withOpacity(0.1),
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
            ),
          ],
        ),
      ),
    );
  }
}
