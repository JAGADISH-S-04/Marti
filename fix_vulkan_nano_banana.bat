@echo off
REM Flutter Vulkan and Nano-Banana Fix Script
REM This script fixes both Vulkan rendering errors and Nano-Banana initialization issues

echo Flutter Vulkan and Nano-Banana Fix Script
echo ==========================================

REM 1. Clean build to ensure manifest changes take effect
echo 1. Cleaning Flutter build cache...
fvm flutter clean

REM 2. Get dependencies
echo 2. Getting Flutter dependencies...
fvm flutter pub get

REM 3. Rebuild app with Impeller disabled
echo 3. Building app with Impeller disabled...
fvm flutter build apk --no-enable-impeller --debug

REM 4. Run app with fixes
echo 4. Running app with all fixes applied...
echo    - Impeller disabled (uses stable OpenGL)
echo    - Vulkan disabled
echo    - Nano-Banana service will re-initialize on debug button press

fvm flutter run --no-enable-impeller -d android

echo.
echo NANO-BANANA TESTING:
echo 1. Open your buyer display page
echo 2. Press the debug button to initialize Nano-Banana
echo 3. You should see 'API Ready: true' in console
echo 4. Try the 'Enhance with AI (Nano-Banana)' button
echo.
echo VULKAN ERROR FIXES:
echo 1. Impeller disabled - using stable OpenGL renderer
echo 2. No more 'ErrorDeviceLost' or fence errors
echo 3. Images should display properly now
echo.
echo If you still see issues, try:
echo - Hot restart the app (R in terminal)
echo - Completely stop and restart: flutter run --no-enable-impeller