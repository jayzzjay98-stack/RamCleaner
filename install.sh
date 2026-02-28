#!/bin/bash
set -e

APP_NAME="RamCleanner"
APP_BUNDLE="${APP_NAME}.app"
INSTALL_DIR="/Applications"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   🔧 RAM Cleaner — Build & Install   ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Step 1: Build
echo "⏳ [1/4] Building..."
swift build -c release 2>&1 | tail -1
echo "   ✅ Build complete"

# Step 2: Create .app bundle
echo "⏳ [2/4] Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy release binary
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.justkay.RamCleanner</string>
    <key>CFBundleName</key>
    <string>RAM Cleaner</string>
    <key>CFBundleDisplayName</key>
    <string>RAM Cleaner</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>RamCleanner</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
echo "   ✅ App bundle created"

# Step 3: Install to /Applications
echo "⏳ [3/4] Installing to ${INSTALL_DIR}..."

# Kill existing instance if running
pkill -f "${INSTALL_DIR}/${APP_BUNDLE}" 2>/dev/null || true
sleep 0.5

# Copy to /Applications (may need password)
if [ -w "${INSTALL_DIR}" ]; then
    rm -rf "${INSTALL_DIR}/${APP_BUNDLE}"
    cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/"
else
    echo "   (requires admin password)"
    sudo rm -rf "${INSTALL_DIR}/${APP_BUNDLE}"
    sudo cp -R "${APP_BUNDLE}" "${INSTALL_DIR}/"
fi
echo "   ✅ Installed to ${INSTALL_DIR}/${APP_BUNDLE}"

# Step 4: Add to Login Items (Launch at startup)
echo "⏳ [4/4] Setting up auto-launch at login..."
osascript -e "
tell application \"System Events\"
    try
        delete login item \"RAM Cleaner\"
    end try
    make login item at end with properties {path:\"${INSTALL_DIR}/${APP_BUNDLE}\", hidden:false}
end tell
" 2>/dev/null && echo "   ✅ Added to Login Items (auto-start on boot)" || echo "   ⚠️  Could not add to Login Items (add manually in System Settings)"

# Clean up local bundle
rm -rf "${APP_BUNDLE}"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        ✅ Installation Complete!      ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "📍 Installed at: ${INSTALL_DIR}/${APP_BUNDLE}"
echo "🚀 Launching now..."
echo ""

open "${INSTALL_DIR}/${APP_BUNDLE}"
