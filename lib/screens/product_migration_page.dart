import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/product_service.dart';

class ProductMigrationPage extends StatefulWidget {
  const ProductMigrationPage({super.key});

  @override
  State<ProductMigrationPage> createState() => _ProductMigrationPageState();
}

class _ProductMigrationPageState extends State<ProductMigrationPage> {
  final ProductService _productService = ProductService();
  bool _isLoading = false;
  String _status = 'Ready to fix likes functionality';
  List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toLocal()}: $message');
    });
    print(message);
  }

  Future<void> _runMigration() async {
    setState(() {
      _isLoading = true;
      _status = 'Fixing likes functionality...';
      _logs.clear();
    });

    try {
      _addLog('Adding likes fields to all products...');
      await _productService.addLikesFieldsToAllProducts();
      _addLog('Likes functionality fixed successfully!');
      
      setState(() {
        _status = 'Likes functionality fixed successfully!';
      });
    } catch (e) {
      _addLog('Fix failed: $e');
      setState(() {
        _status = 'Fix failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetLikes() async {
    setState(() {
      _isLoading = true;
      _status = 'Resetting likes...';
    });

    try {
      _addLog('Resetting all product likes...');
      
      // Reset all likes using Firestore batch
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore.collection('products').get();
      final batch = firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'likes': 0,
          'likedBy': [],
        });
      }
      
      await batch.commit();
      _addLog('All likes have been reset to zero!');
      
      setState(() {
        _status = 'All likes reset successfully!';
      });
    } catch (e) {
      _addLog('Reset failed: $e');
      setState(() {
        _status = 'Reset failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkStats() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking product stats...';
    });

    try {
      _addLog('Getting product statistics...');
      
      // Get products with most likes
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final mostLikedQuery = await firestore
          .collection('products')
          .orderBy('likes', descending: true)
          .limit(5)
          .get();
      
      final mostViewedQuery = await firestore
          .collection('products')
          .orderBy('views', descending: true)
          .limit(5)
          .get();
      
      _addLog('=== MOST LIKED PRODUCTS ===');
      for (final doc in mostLikedQuery.docs) {
        final data = doc.data();
        _addLog('${data['name']}: ${data['likes'] ?? 0} likes');
      }
      
      _addLog('=== MOST VIEWED PRODUCTS ===');
      for (final doc in mostViewedQuery.docs) {
        final data = doc.data();
        _addLog('${data['name']}: ${data['views'] ?? 0} views');
      }
      
      setState(() {
        _status = 'Stats retrieved successfully!';
      });
    } catch (e) {
      _addLog('Stats check failed: $e');
      setState(() {
        _status = 'Stats check failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Likes Functionality'),
        backgroundColor: const Color(0xFF2C1810),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fix Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _status.contains('failed') ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _runMigration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Fix Likes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetLikes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset Likes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkStats,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Check Stats'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fix Logs',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey.shade50,
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _logs.isEmpty ? 'No logs yet...' : _logs.join('\n'),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
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
      ),
    );
  }
}
