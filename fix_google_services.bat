@echo off
echo Fixing Google Services Authentication Issues...
echo.

echo Step 1: Cleaning Flutter project...
flutter clean

echo Step 2: Getting Flutter dependencies...
flutter pub get

echo Step 3: Cleaning Android build...
cd android
./gradlew clean
cd ..

echo Step 4: Building APK with proper Google Services...
flutter build apk --debug

echo Step 5: Installing on connected device...
flutter install

echo.
echo Google Services fix completed!
echo If you still see authentication errors, try:
echo 1. Restart the device
echo 2. Clear app data and cache
echo 3. Ensure Google Play Services is updated on the device
pause