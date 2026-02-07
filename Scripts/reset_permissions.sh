#!/bin/bash

# Reset Permissions Script for openwispher Development
# This script resets all app permissions and preferences for clean testing

APP_BUNDLE_ID="sphereai.in.openwispher"

echo "🧹 Resetting openwispher permissions and preferences..."
echo ""

# Reset app preferences
echo "📦 Clearing app preferences..."
defaults delete "$APP_BUNDLE_ID" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ App preferences cleared"
else
    echo "   ℹ️  No preferences to clear"
fi

# Clear caches
echo "🗑️  Clearing app caches..."
rm -rf ~/Library/Caches/"$APP_BUNDLE_ID" 2>/dev/null
echo "   ✅ Caches cleared"

# Reset microphone permission
echo "🎤 Resetting microphone permission..."
tccutil reset Microphone "$APP_BUNDLE_ID" 2>&1 | grep -q "Successfully reset"
if [ $? -eq 0 ]; then
    echo "   ✅ Microphone permission reset"
else
    echo "   ℹ️  Microphone permission wasn't set or already reset"
fi

# Reset accessibility permission
echo "🔓 Resetting accessibility permission..."
tccutil reset Accessibility "$APP_BUNDLE_ID" 2>&1 | grep -q "Successfully reset"
if [ $? -eq 0 ]; then
    echo "   ✅ Accessibility permission reset"
else
    echo "   ℹ️  Accessibility permission wasn't set or already reset"
fi

echo ""
echo "✨ Reset complete! The app will now show onboarding on next launch."
echo ""
echo "📝 Note: If accessibility permission doesn't prompt, you may need to:"
echo "   1. Open System Settings > Privacy & Security > Accessibility"
echo "   2. Manually remove 'openwispher' from the list"
echo "   3. Relaunch the app"
