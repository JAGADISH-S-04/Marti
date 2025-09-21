# FAQ Management System - Admin Access Control

## Overview
The FAQ Management System now includes comprehensive admin access control to ensure only authorized users can manage FAQ content.

## Admin Access Levels

### Public Access (All Users)
- ✅ **View FAQs** - Both buyers and retailers can view their respective FAQ sections
- ✅ **Search FAQs** - All users can search through FAQ content
- ✅ **Submit Feedback** - Users can rate FAQ helpfulness

### Admin Only Access
- 🔒 **FAQ Management** - Create, edit, delete FAQs
- 🔒 **FAQ Data Setup** - Initialize sample data, view statistics
- 🔒 **Admin User Management** - Add/remove other admin users

## How Admin Access Works

### 1. Admin Email Verification
The system checks if the current user's email is in the predefined admin list:
```dart
// In AdminService
static const List<String> _adminEmails = [
  'admin@arti.com',
  'mouli@arti.com', 
  'jagadish@arti.com',
  'jagadishkanagaraj04@gmail.com', // Your email
];
```

### 2. Database Admin Collection
- Verified admin users are stored in Firestore `admin_users` collection
- Each admin has: `userId`, `email`, `isAdmin: true`, `isActive: true`, `addedAt`
- Provides fast lookup for admin status checking

### 3. Access Control Flow
```
User clicks "Manage FAQs" → AdminService.hasAdminAccess('faq_management')
→ Check Firestore admin_users collection
→ Fallback to predefined admin emails list
→ Grant/Deny access + Show appropriate dialog
```

## Testing Admin Access

### For Current User (Your Email)
1. **Go to Seller Dashboard** → Click **Help icon** (top right)
2. **Select "FAQ Setup"** from dropdown menu
3. **Click "Check Admin Status"** button
4. **Verify your admin access** - Should show "YES ✅" for all checks

### Admin Menu Access
- **Orange colored menu items** indicate admin-only features
- **"Manage FAQs"** - Full CRUD interface for FAQ management
- **"FAQ Setup"** - Data initialization and statistics

### If Access Denied
- Users see a security dialog: "This feature is restricted to administrators only"
- Navigation is blocked and user is returned to previous screen

## Admin Features

### 1. FAQ Management Screen (`/admin/faq_management_screen.dart`)
- **Overview Tab**: Statistics dashboard, quick actions
- **Customer FAQs Tab**: Manage buyer-focused FAQs  
- **Retailer FAQs Tab**: Manage seller-focused FAQs
- **Full CRUD**: Create, read, update, delete FAQs
- **Real-time updates**: Changes sync immediately across all users

### 2. FAQ Data Initializer (`/admin/faq_data_initializer_screen.dart`)
- **Initialize Sample Data**: Pre-populate FAQ system
- **View Statistics**: Count of FAQs, views, ratings
- **Check Admin Status**: Debug current user permissions

### 3. Admin User Management (`/admin/admin_user_management_screen.dart`)
- **View All Admins**: List of current admin users
- **Add Admin Users**: Grant admin privileges (by email)
- **Remove Admin Users**: Revoke admin privileges
- **Self-protection**: Cannot remove own admin access

## Security Implementation

### Frontend Protection
```dart
// Check before navigation
if (await AdminService.hasAdminAccess('faq_management')) {
  // Navigate to admin screen
} else {
  AdminService.showAdminAccessDeniedDialog(context);
}
```

### Screen-Level Protection
```dart
// In admin screen initState()
Future<void> _checkAdminAccess() async {
  if (!await AdminService.hasAdminAccess('faq_management')) {
    AdminService.showAdminAccessDeniedDialog(context);
    Navigator.pop(context);
  }
}
```

### Backend Protection (Firestore Rules)
```javascript
// In firestore.rules
match /faqs/{faqId} {
  allow write: if isAdmin(request.auth.uid);
  allow read: if true; // FAQs are public
}

match /admin_users/{userId} {
  allow read, write: if isAdmin(request.auth.uid);
}
```

## Current Admin Users
- **jagadishkanagaraj04@gmail.com** - Primary admin (you)
- Additional admins can be added through the Admin User Management screen

## Usage Instructions

### For Regular Users
- Access **View FAQ** from Help menu - No restrictions
- All FAQ viewing and search functionality available

### For Admins
1. **Access FAQ Management**: Help → "Manage FAQs" (orange text)
2. **Initialize Data**: Help → "FAQ Setup" → "Initialize Sample Data" 
3. **Check Status**: Help → "FAQ Setup" → "Check Admin Status"
4. **Manage Users**: Available in future updates

## Error Handling
- **Network Issues**: Graceful degradation with retry options
- **Permission Errors**: Clear error messages with contact info
- **Invalid Data**: Validation with helpful error descriptions

The admin system ensures FAQ content integrity while maintaining a smooth user experience for all users.