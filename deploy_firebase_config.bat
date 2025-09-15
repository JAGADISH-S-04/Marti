@echo off
echo Deploying Firebase configuration for Reviews System...
echo.

echo 1. Deploying Firestore indexes...
firebase deploy --only firestore:indexes

echo.
echo 2. Deploying Firestore security rules...
firebase deploy --only firestore:rules

echo.
echo 3. Firebase configuration deployment complete!
echo.
echo Note: Indexes may take a few minutes to build in Firebase Console.
echo You can monitor the progress at: https://console.firebase.google.com/project/garti-sans/firestore/indexes

pause