import 'package:flutter/material.dart';
import '../../services/product_migration_service.dart';

class ProductMigrationScreen extends StatefulWidget {
  const ProductMigrationScreen({Key? key}) : super(key: key);

  @override
  State<ProductMigrationScreen> createState() => _ProductMigrationScreenState();
}

class _ProductMigrationScreenState extends State<ProductMigrationScreen> {
  final ProductMigrationService _migrationService = ProductMigrationService();
  
  bool _isMigrating = false;
  bool _isCheckingStatus = false;
  Map<String, dynamic>? _migrationStatus;
  String _migrationLog = '';

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Migration'),
        backgroundColor: Colors.brown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Migration Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 20),
            
            // Migration Controls
            _buildControlsCard(),
            
            const SizedBox(height: 20),
            
            // Migration Log
            _buildLogCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Migration Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 12),
            
            if (_isCheckingStatus)
              const Center(child: CircularProgressIndicator())
            else if (_migrationStatus != null) ...[
              _buildStatusRow('Total Products', '${_migrationStatus!['totalProducts']}'),
              _buildStatusRow('Migrated', '${_migrationStatus!['migratedProducts']}'),
              _buildStatusRow('Pending', '${_migrationStatus!['unmigratedProducts']}'),
              _buildStatusRow('Progress', '${_migrationStatus!['migrationPercentage']}%'),
              
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_migrationStatus!['migrationPercentage'] as int) / 100,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.brown),
              ),
            ] else
              const Text('Unable to load migration status'),
            
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingStatus ? null : _checkMigrationStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Migration Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
            const SizedBox(height: 12),
            
            const Text(
              'This will migrate your existing products to the new organized storage structure:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            
            const Text(
              '• Downloads existing images/videos\n'
              '• Re-uploads to organized folders\n'
              '• Updates database with new URLs\n'
              '• Adds search terms and metadata',
              style: TextStyle(fontSize: 14),
            ),
            
            const SizedBox(height: 16),
            
            if (_migrationStatus != null && _migrationStatus!['unmigratedProducts'] > 0) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isMigrating ? null : _startMigration,
                  icon: _isMigrating 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_isMigrating ? 'Migrating...' : 'Start Migration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Migration may take several minutes depending on the number of products and file sizes.',
                        style: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_migrationStatus != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'All products have been migrated to the new structure!',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Migration Log',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _migrationLog = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear Log',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _migrationLog.isEmpty 
                          ? 'Migration log will appear here...' 
                          : _migrationLog,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _migrationLog.isEmpty ? Colors.grey : Colors.black,
                      ),
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

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _checkMigrationStatus() async {
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final status = await _migrationService.getMigrationStatus();
      setState(() {
        _migrationStatus = status;
      });
      
      _addToLog('✅ Migration status updated');
    } catch (e) {
      _addToLog('❌ Failed to check migration status: $e');
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _startMigration() async {
    final confirm = await _showConfirmationDialog();
    if (!confirm) return;

    setState(() {
      _isMigrating = true;
      _migrationLog = '';
    });

    _addToLog('🚀 Starting product migration...');

    try {
      await _migrationService.migrateAllProducts();
      
      _addToLog('🎉 Migration completed successfully!');
      
      // Refresh status
      await _checkMigrationStatus();
      
    } catch (e) {
      _addToLog('💥 Migration failed: $e');
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Migration'),
        content: const Text(
          'This will migrate all your existing products to the new organized storage structure. '
          'This process may take several minutes and cannot be easily undone.\n\n'
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Start Migration', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _addToLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _migrationLog += '[$timestamp] $message\n';
    });
  }
}
