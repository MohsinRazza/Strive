#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Strive — Build .deb Package for Debian/Ubuntu
# ─────────────────────────────────────────────────────────────
# Usage:  chmod +x build_deb.sh && ./build_deb.sh
# Output: ./build/strive_<version>_amd64.deb
# ─────────────────────────────────────────────────────────────

set -e  # Exit on any error

# ── Configuration ──
APP_NAME="strive"
APP_DISPLAY_NAME="Strive"
APP_VERSION="1.0.0"
APP_DESCRIPTION="A minimal, distraction-free study timer and focus tracker."
APP_MAINTAINER="Mohsin Razza <mohsin@silinode.com>"
APP_HOMEPAGE="https://github.com/MohsinRazza/Strive"
ARCH="amd64"

# ── Paths ──
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
BUNDLE_DIR="${BUILD_DIR}/linux/x64/release/bundle"
DEB_ROOT="${BUILD_DIR}/${APP_NAME}_${APP_VERSION}_${ARCH}"
DEB_OUTPUT="${BUILD_DIR}/${APP_NAME}_${APP_VERSION}_${ARCH}.deb"

echo "╔══════════════════════════════════════════════╗"
echo "║   Strive .deb Package Builder                ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Step 1: Build Flutter Linux release ──
echo "▸ [1/5] Building Flutter Linux release..."
cd "${PROJECT_DIR}"
flutter pub get
flutter build linux --release

if [ ! -d "${BUNDLE_DIR}" ]; then
    echo "✗ Error: Flutter build output not found at ${BUNDLE_DIR}"
    exit 1
fi
echo "  ✓ Flutter build complete."

# ── Step 2: Create .deb directory structure ──
echo "▸ [2/5] Creating .deb package structure..."
rm -rf "${DEB_ROOT}"

# Standard Debian directories
mkdir -p "${DEB_ROOT}/DEBIAN"
mkdir -p "${DEB_ROOT}/usr/lib/${APP_NAME}"
mkdir -p "${DEB_ROOT}/usr/bin"
mkdir -p "${DEB_ROOT}/usr/share/applications"
# Create icon dirs for all standard hicolor sizes
for SIZE in 16 24 32 48 64 96 128 256; do
    mkdir -p "${DEB_ROOT}/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"
done

echo "  ✓ Directory structure created."

# ── Step 3: Copy application files ──
echo "▸ [3/5] Copying application bundle..."

# Copy the entire Flutter bundle
cp -r "${BUNDLE_DIR}/"* "${DEB_ROOT}/usr/lib/${APP_NAME}/"

# Create symlink launcher in /usr/bin
cat > "${DEB_ROOT}/usr/bin/${APP_NAME}" << 'LAUNCHER'
#!/bin/bash
exec /usr/lib/strive/strive "$@"
LAUNCHER
chmod 755 "${DEB_ROOT}/usr/bin/${APP_NAME}"

# Copy and resize app icon to all standard hicolor sizes
if [ -f "${PROJECT_DIR}/assets/images/logo_s.png" ]; then
    if command -v convert &> /dev/null; then
        for SIZE in 16 24 32 48 64 96 128 256; do
            convert "${PROJECT_DIR}/assets/images/logo_s.png" \
                -resize "${SIZE}x${SIZE}" \
                "${DEB_ROOT}/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps/${APP_NAME}.png"
        done
        echo "  ✓ App icons generated at all sizes."
    else
        # Fallback: just copy at 256x256 if ImageMagick not available
        cp "${PROJECT_DIR}/assets/images/logo_s.png" \
           "${DEB_ROOT}/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png"
        echo "  ⚠ ImageMagick not found — only 256x256 icon copied."
        echo "    Install with: sudo apt install imagemagick"
    fi
fi

echo "  ✓ Bundle copied."

# ── Step 4: Create package metadata ──
echo "▸ [4/5] Writing package metadata..."

# DEBIAN/control
cat > "${DEB_ROOT}/DEBIAN/control" << EOF
Package: ${APP_NAME}
Version: ${APP_VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: ${APP_MAINTAINER}
Homepage: ${APP_HOMEPAGE}
Description: ${APP_DESCRIPTION}
 Strive is a minimalist desktop study timer built with Flutter.
 Features include a distraction-free focus timer, activity heatmap,
 daily performance tracking with lap-based session logs, and
 full import/export of study history.
Depends: libgtk-3-0, libblkid1, liblzma5
EOF

# .desktop launcher entry
cat > "${DEB_ROOT}/usr/share/applications/${APP_NAME}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${APP_DISPLAY_NAME}
Comment=${APP_DESCRIPTION}
Exec=${APP_NAME}
Icon=${APP_NAME}
Terminal=false
Categories=Utility;Office;Education;
Keywords=study;timer;focus;pomodoro;productivity;
StartupWMClass=strive
EOF

# Post-install script (update icon cache so dock/multitasking sees the icon)
cat > "${DEB_ROOT}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
# Force-refresh the hicolor icon theme cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache --force --ignore-theme-index /usr/share/icons/hicolor/ 2>/dev/null || true
fi
# Update .desktop database so the app is findable
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database /usr/share/applications/ 2>/dev/null || true
fi
EOF
chmod 755 "${DEB_ROOT}/DEBIAN/postinst"

echo "  ✓ Metadata written."

# ── Step 5: Build .deb ──
echo "▸ [5/5] Building .deb package..."

# Fix permissions
find "${DEB_ROOT}" -type d -exec chmod 755 {} \;
find "${DEB_ROOT}/usr" -type f -exec chmod 644 {} \;
chmod 755 "${DEB_ROOT}/usr/bin/${APP_NAME}"
chmod 755 "${DEB_ROOT}/usr/lib/${APP_NAME}/${APP_NAME}"
# Make all .so files executable
find "${DEB_ROOT}/usr/lib/${APP_NAME}" -name "*.so" -exec chmod 755 {} \;

dpkg-deb --build "${DEB_ROOT}" "${DEB_OUTPUT}"

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Package built successfully!"
echo "  → ${DEB_OUTPUT}"
echo ""
echo "  Install:   sudo dpkg -i ${DEB_OUTPUT}"
echo "  Uninstall: sudo dpkg -r ${APP_NAME}"
echo "═══════════════════════════════════════════════"
