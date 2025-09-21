# Product Migration Guide

## Quick Start - Migrate Your Existing Products

Your existing products are currently stored in an unorganized structure. This migration will move them to the new organized structure: `buyer_display/{seller_name}/{product_id}/images/`

### 🚀 Quick Migration (Recommended)

#### Option 1: Using Flutter App UI
1. **Add migration screen to your app**:
```dart
// In your main app, add this route:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ProductMigrationScreen(),
  ),
);
```

2. **Run the app and navigate to migration screen**
3. **Click "Start Migration"** - the UI will show progress and logs
4. **Wait for completion** - typically 1-5 minutes depending on product count

#### Option 2: Console Migration (Fastest)
1. **Run the migration script**:
```bash
flutter run migration_runner.dart
```

2. **Watch the console output** for progress
3. **Migration completes automatically**

### 📋 What Happens During Migration

1. **Downloads** your existing product images/videos from current locations
2. **Re-uploads** them to organized folders: `buyer_display/{seller_name}/{product_id}/images/`
3. **Updates** your Firestore database with new URLs and enhanced metadata
4. **Adds** search optimization (search terms, price ranges)
5. **Preserves** all original data (no data loss)

### 🔍 Check Migration Status

Run this code to see current status:
```dart
final migrationService = ProductMigrationService();
final status = await migrationService.getMigrationStatus();

print('Total Products: ${status['totalProducts']}');
print('Migrated: ${status['migratedProducts']}');
print('Pending: ${status['unmigratedProducts']}');
print('Progress: ${status['migrationPercentage']}%');
```

### 📁 Before vs After Structure

**Before (Unorganized)**:
```
storage/products/
├── random_image_1.jpg
├── random_image_2.jpg
├── random_image_3.jpg
└── ...
```

**After (Organized)**:
```
storage/buyer_display/
├── johns_crafts/
│   ├── product_123/images/
│   │   ├── main_display_123456.jpg
│   │   └── image_1_123457.jpg
│   └── product_456/images/
├── marias_pottery/
│   └── product_789/images/
└── ...
```

### ⚠️ Important Notes

- **Safe Process**: Original files are kept until manually deleted
- **Resumable**: If migration fails, you can re-run it
- **No Downtime**: Your app continues working during migration
- **Backup Recommended**: Though safe, consider backing up your Firebase project

### 🛠️ Troubleshooting

**Migration appears stuck?**
- Check your internet connection
- Large files take longer to download/upload
- Console shows detailed progress

**Some products failed to migrate?**
- Failed products keep their original URLs
- Check the logs for specific error messages
- You can re-run migration for specific products

**Need to rollback?**
- Original URLs are preserved in the database
- Contact support for rollback assistance

### 📞 Need Help?

If you encounter any issues:
1. Check the console logs for error details
2. Ensure you have proper Firebase permissions
3. Verify your internet connection is stable
4. Review the implementation guide for troubleshooting steps

**Ready to migrate?** Run one of the migration options above to get started!
