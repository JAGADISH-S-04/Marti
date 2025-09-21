import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/product_migration_service.dart';
import 'lib/screens/admin/product_migration_screen.dart';

// Simple migration runner app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  runApp(const MigrationApp());
}

class MigrationApp extends StatelessWidget {
  const MigrationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Migration Tool',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ProductMigrationScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Alternative: Simple console migration
class ConsoleMigration {
  static Future<void> run() async {
    print('🚀 Starting Firebase initialization...');
    await Firebase.initializeApp();
    
    print('🚀 Starting product migration...');
    final migrationService = ProductMigrationService();
    
    try {
      // Check current status
      print('📊 Checking migration status...');
      final status = await migrationService.getMigrationStatus();
      
      print('📋 Migration Status:');
      print('   Total Products: ${status['totalProducts']}');
      print('   Migrated: ${status['migratedProducts']}');
      print('   Pending: ${status['unmigratedProducts']}');
      print('   Progress: ${status['migrationPercentage']}%');
      
      if (status['unmigratedProducts'] > 0) {
        print('\n🔄 Starting migration...');
        await migrationService.migrateAllProducts();
        print('✅ Migration completed!');
      } else {
        print('✅ All products are already migrated!');
      }
      
    } catch (e) {
      print('❌ Migration failed: $e');
    }
  }
}
