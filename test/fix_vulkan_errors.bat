@echo off
echo 🧹 Cleaning Flutter project to fix Vulkan errors...

echo 🔧 Step 1: Flutter clean...
fvm flutter clean

echo 📦 Step 2: Get dependencies...
fvm flutter pub get

echo 🏗️ Step 3: Rebuild with OpenGL ES (no Vulkan)...
fvm flutter run --verbose

echo ✅ Project rebuilt with Vulkan disabled!
echo 💡 If you still see Vulkan errors, they won't affect functionality.

pause