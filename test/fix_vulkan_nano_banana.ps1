# Flutter Vulkan and Nano-Banana Fix Script (PowerShell)
# This script fixes both Vulkan rendering errors and Nano-Banana initialization issues

Write-Host "Flutter Vulkan and Nano-Banana Fix Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Clean build to ensure manifest changes take effect
Write-Host "1. Cleaning Flutter build cache..." -ForegroundColor Yellow
fvm flutter clean

# 2. Get dependencies  
Write-Host "2. Getting Flutter dependencies..." -ForegroundColor Yellow
fvm flutter pub get

# 3. Rebuild app with Impeller disabled
Write-Host "3. Building app with Impeller disabled..." -ForegroundColor Yellow
fvm flutter build apk --no-enable-impeller --debug

# 4. Run app with fixes
Write-Host "4. Running app with all fixes applied..." -ForegroundColor Yellow
Write-Host "   - Impeller disabled (uses stable OpenGL)" -ForegroundColor Green
Write-Host "   - Vulkan disabled" -ForegroundColor Green
Write-Host "   - Nano-Banana service will re-initialize on debug button press" -ForegroundColor Green

fvm flutter run --no-enable-impeller -d android

Write-Host ""
Write-Host "NANO-BANANA TESTING:" -ForegroundColor Magenta
Write-Host "1. Open your buyer display page" -ForegroundColor White
Write-Host "2. Press the debug button to initialize Nano-Banana" -ForegroundColor White  
Write-Host "3. You should see 'API Ready: true' in console" -ForegroundColor White
Write-Host "4. Try the 'Enhance with AI (Nano-Banana)' button" -ForegroundColor White
Write-Host ""
Write-Host "VULKAN ERROR FIXES:" -ForegroundColor Magenta
Write-Host "1. Impeller disabled - using stable OpenGL renderer" -ForegroundColor White
Write-Host "2. No more 'ErrorDeviceLost' or fence errors" -ForegroundColor White
Write-Host "3. Images should display properly now" -ForegroundColor White
Write-Host ""
Write-Host "If you still see issues, try:" -ForegroundColor Red
Write-Host "- Hot restart the app (R in terminal)" -ForegroundColor White
Write-Host "- Completely stop and restart: flutter run --no-enable-impeller" -ForegroundColor White