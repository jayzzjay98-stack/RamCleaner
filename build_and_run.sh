#!/bin/bash
set -e

APP_NAME="RamCleanner"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/debug"

echo "🔨 Building ${APP_NAME}..."
swift build

echo "📦 Creating app bundle..."

# Create .app bundle structure
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "Info.plist" "${APP_BUNDLE}/Contents/"

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "✅ Built ${APP_BUNDLE} successfully!"
echo ""
echo "🚀 Launching..."
open "${APP_BUNDLE}"
