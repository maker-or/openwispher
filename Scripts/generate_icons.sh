#!/bin/bash

# Icon Generator Script for openwispher
# Generates all required macOS icon sizes from a single 1024×1024 source image

set -e

echo "🎨 openwispher Icon Generator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if source image is provided
if [ -z "$1" ]; then
    echo "❌ Error: No source image provided"
    echo ""
    echo "Usage: ./generate_icons.sh <path-to-1024x1024-icon.png>"
    echo ""
    echo "Example:"
    echo "  ./generate_icons.sh ~/Desktop/openwispher-icon.png"
    echo ""
    echo "Requirements:"
    echo "  - Source image must be 1024×1024 PNG"
    echo "  - High quality, clear design"
    echo "  - Preferably with transparent or solid background"
    exit 1
fi

SOURCE_IMAGE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/../openwispher/Assets.xcassets/AppIcon.appiconset"

# Verify source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: Source image not found: $SOURCE_IMAGE"
    exit 1
fi

# Verify output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ Error: Output directory not found: $OUTPUT_DIR"
    exit 1
fi

echo "📁 Source: $SOURCE_IMAGE"
echo "📁 Output: $OUTPUT_DIR"
echo ""

# Check image dimensions
IMAGE_SIZE=$(sips -g pixelWidth -g pixelHeight "$SOURCE_IMAGE" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
echo "📐 Source dimensions: $IMAGE_SIZE"

if [[ ! "$IMAGE_SIZE" =~ ^1024x1024$ ]]; then
    echo "⚠️  Warning: Source image is not 1024×1024. Results may be suboptimal."
    echo "   Continuing anyway..."
    echo ""
fi

echo ""
echo "🔄 Generating icon sizes..."
echo ""

# Define all required icon sizes for macOS
declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

# Generate each size
for ENTRY in "${SIZES[@]}"; do
    SIZE="${ENTRY%%:*}"
    FILENAME="${ENTRY##*:}"
    OUTPUT_PATH="$OUTPUT_DIR/$FILENAME"

    printf "   %-25s → %4d×%-4d ... " "$FILENAME" "$SIZE" "$SIZE"

    # Use sips to resize
    sips -z "$SIZE" "$SIZE" "$SOURCE_IMAGE" --out "$OUTPUT_PATH" > /dev/null 2>&1

    if [ -f "$OUTPUT_PATH" ]; then
        FILE_SIZE=$(ls -lh "$OUTPUT_PATH" | awk '{print $5}')
        echo "✅ ($FILE_SIZE)"
    else
        echo "❌ Failed"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Icon Generation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📂 Icons saved to:"
echo "   $OUTPUT_DIR"
echo ""
echo "🎯 Next Steps:"
echo "   1. Open Xcode"
echo "   2. Clean Build Folder (Cmd+Shift+K)"
echo "   3. Build & Run (Cmd+R)"
echo "   4. Your new icon should appear in the Dock!"
echo ""
echo "💡 Tip: If icon doesn't update:"
echo "   - Restart Xcode"
echo "   - Run: sudo killall Finder Dock"
echo "   - Delete and reinstall the app"
echo ""
