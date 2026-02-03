#!/bin/bash

# Restart App Script for Dhavnii
# This script restarts the application after accessibility permission is granted
# Usage: ./restart_app.sh [app_bundle_path]

APP_BUNDLE_PATH="${1:-/Applications/dhavnii.app}"

echo "🔄 Restarting Dhavnii..."
echo "   App path: $APP_BUNDLE_PATH"

# Check if app exists
if [ ! -d "$APP_BUNDLE_PATH" ]; then
    echo "❌ App not found at: $APP_BUNDLE_PATH"
    exit 1
fi

# Get the app executable name (usually same as bundle name without .app)
APP_NAME=$(basename "$APP_BUNDLE_PATH" .app)

# Kill any running instances
echo "   Stopping existing instances..."
pkill -f "$APP_NAME" 2>/dev/null

# Wait a moment for processes to terminate
sleep 0.5

# Launch the app
echo "   Launching app..."
open "$APP_BUNDLE_PATH"

echo "✅ App restarted successfully"
