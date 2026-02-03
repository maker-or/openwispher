#!/bin/bash

# Dhavnii Release Build Script
# Builds a Release version and installs it to Applications folder

set -e  # Exit on error

APP_NAME="dhavnii"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="dhavnii"

echo "🚀 Building Dhavnii Release Version..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app directly
echo "🔨 Building Release configuration..."
cd "$PROJECT_DIR"

xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build completed"
echo ""

# Find the built app
BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)

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
if [ -d "/Applications/$APP_NAME.app" ]; then
    echo "   Removing old version..."
    rm -rf "/Applications/$APP_NAME.app"
fi

cp -R "$BUILT_APP" /Applications/

# Remove quarantine attribute
echo "🔓 Removing quarantine flag..."
xattr -cr "/Applications/$APP_NAME.app"

# Get app info
APP_SIZE=$(du -sh "/Applications/$APP_NAME.app" | cut -f1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Location: /Applications/$APP_NAME.app"
echo "💾 Size:     $APP_SIZE"
echo ""
echo "🎯 Next Steps:"
echo "   1. Open Finder > Applications"
echo "   2. Find '$APP_NAME' and drag it to your Dock"
echo "   3. Double-click to launch"
echo "   4. Grant permissions when prompted"
echo "   5. Press Option+Space to start using!"
echo ""

# Open Applications folder
echo "📂 Opening Applications folder..."
open /Applications

echo "🎉 Done! Your app is ready to use."
