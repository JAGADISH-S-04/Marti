@echo off
echo ============================================
echo Firebase Project Migration Script
echo ============================================
echo.
echo This script will help you migrate to a new Firebase project
echo Make sure you have:
echo 1. Created a new Firebase project with 22138053@student.hindustanuniv.ac.in
echo 2. Enabled Authentication, Firestore, and Storage
echo 3. Downloaded the new google-services.json file
echo.
pause

echo Step 1: Backing up current configuration...
copy android\app\google-services.json android\app\google-services-backup.json
echo ✅ Current configuration backed up

echo.
echo Step 2: Please replace android\app\google-services.json with your new file
echo Press any key when you have replaced the file...
pause

echo.
echo Step 3: Regenerating Firebase configuration...
flutter pub global run flutterfire_cli:flutterfire configure

echo.
echo Step 4: Cleaning and rebuilding...
flutter clean
flutter pub get

echo.
echo Step 5: Testing the new configuration...
echo Please run: flutter run
echo Then try uploading a buyer display image to test Firebase Storage

echo.
echo ============================================
echo Migration completed!
echo ============================================
echo.
echo If you encounter any errors:
echo 1. Check Firebase Storage rules are set to allow authenticated uploads
echo 2. Verify Firestore rules allow authenticated read/write
echo 3. Ensure Authentication is enabled with Email/Password and Google
echo.
pause
