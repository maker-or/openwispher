#!/bin/bash

# openwispher Release Build Script
# Builds a Release version and installs it to Applications folder

set -e  # Exit on error

PROJECT_NAME="openwispher"
RELEASE_APP_NAME="OpenWispher"
APP_BUNDLE_ID="in.sphereai.openwispher"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="openwispher"

echo "🚀 Building openwispher Release Version..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app directly
echo "🔨 Building Release configuration..."
cd "$PROJECT_DIR"

xcodebuild -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    PRODUCT_NAME="$RELEASE_APP_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build completed"
echo ""

# Find the built app
BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "$RELEASE_APP_NAME.app" -type d | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "❌ Could not find built app!"
    echo "Searching in: $BUILD_DIR/DerivedData"
    find "$BUILD_DIR/DerivedData" -name "*.app" -type d
    exit 1
fi

echo "📦 Found app at: $BUILT_APP"
echo ""

# Install to Applications
echo "📲 Installing to /Applications/..."
if [ -d "/Applications/$RELEASE_APP_NAME.app" ]; then
    echo "   Removing old version..."
    rm -rf "/Applications/$RELEASE_APP_NAME.app"
fi

if [ -d "/Applications/$PROJECT_NAME.app" ]; then
    echo "   Removing legacy app name..."
    rm -rf "/Applications/$PROJECT_NAME.app"
fi

cp -R "$BUILT_APP" /Applications/

# Quit running app so preferences reset applies on next launch
echo "🛑 Quitting running app if needed..."
if pgrep -x "$PROJECT_NAME" > /dev/null; then
    osascript -e "tell application \"$PROJECT_NAME\" to quit" || true
    sleep 1
    pkill -x "$PROJECT_NAME" || true
fi

if pgrep -x "$RELEASE_APP_NAME" > /dev/null; then
    osascript -e "tell application \"$RELEASE_APP_NAME\" to quit" || true
    sleep 1
    pkill -x "$RELEASE_APP_NAME" || true
fi

# Reset onboarding state so release starts onboarding
echo "🧼 Resetting onboarding state..."
defaults delete "$APP_BUNDLE_ID" hasCompletedOnboarding 2>/dev/null || true
defaults delete "$APP_BUNDLE_ID" 2>/dev/null || true
defaults write "$APP_BUNDLE_ID" forceOnboardingOnLaunch -bool true

# Remove quarantine attribute
echo "🔓 Removing quarantine flag..."
xattr -cr "/Applications/$RELEASE_APP_NAME.app"

# Get app info
APP_SIZE=$(du -sh "/Applications/$RELEASE_APP_NAME.app" | cut -f1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: /Applications/$RELEASE_APP_NAME.app"
echo "💾 Size:     $APP_SIZE"
echo ""
echo "🎯 Next Steps:"
echo "   1. Open Finder > Applications"
echo "   2. Find '$RELEASE_APP_NAME' and drag it to your Dock"
echo "   3. Double-click to launch"
echo "   4. Grant permissions when prompted"
echo "   5. Press Option+Space to start using!"
echo ""

# Open Applications folder
echo "📂 Opening Applications folder..."
open /Applications

echo "🎉 Done! Your app is ready to use."
