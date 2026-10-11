#!/usr/bin/env bash
#
# build-dmg.sh - Build and package RClickX into a macOS DMG installer
# Supports create-dmg (if installed) or native hdiutil fallback.
#

set -euo pipefail

# --- Configuration & Defaults ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RClick"
DISPLAY_NAME="RClickX"
SCHEME="RClick"
PROJECT="RClick.xcodeproj"
CONFIGURATION="Release"
OUTPUT_DIR="${PROJECT_DIR}/dist"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
SKIP_BUILD=false
VERSION=""

# --- Helper Functions ---
log_info() {
    printf "\033[1;34m[INFO]\033[0m %s\n" "$*"
}

log_success() {
    printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$*"
}

log_warn() {
    printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
}

log_error() {
    printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -v, --version <VERSION>      Specify version string (e.g., 2.1.0). Defaults to marketing version in Xcode project.
    -c, --config <CONFIGURATION> Build configuration (Release or Debug). Default: Release.
    -o, --output <DIR>           Output directory for DMG and artifacts. Default: ./dist.
    -s, --sign <IDENTITY>        Code signing identity. Uses local Apple Development when available; otherwise ad-hoc.
    --skip-build                 Skip xcodebuild step and package existing build in build folder.
    -h, --help                   Show this help message.

Examples:
    ./scripts/build-dmg.sh
    ./scripts/build-dmg.sh --version 2.2.0 --config Release
    ./scripts/build-dmg.sh --sign "Developer ID Application: Your Name (TEAMID)"
EOF
}

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -c|--config)
            CONFIGURATION="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--sign)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

# Finder Sync extensions on recent macOS releases need an embedded
# provisioning profile to be discoverable by PlugInKit. Prefer the local
# Apple Development identity when the caller did not provide one, and only
# fall back to an ad-hoc package when no certificate is available.
if [ -z "$SIGNING_IDENTITY" ] && command -v security >/dev/null 2>&1; then
    if security find-identity -v -p codesigning 2>/dev/null | grep -q '"Apple Development:'; then
        SIGNING_IDENTITY="Apple Development"
        log_info "No signing identity supplied; using the local Apple Development profile so FinderSync can be registered."
    fi
fi

# --- Determine Version ---
if [ -z "$VERSION" ]; then
    VERSION=$(xcodebuild -project "$PROJECT" -showBuildSettings -configuration "$CONFIGURATION" 2>/dev/null \
        | awk -F ' = ' '/MARKETING_VERSION/ {print $2; exit}' || true)
    if [ -z "$VERSION" ]; then
        VERSION="2.1.0"
    fi
fi

log_info "Packaging $DISPLAY_NAME version: $VERSION ($CONFIGURATION)"

BUILD_DIR="${PROJECT_DIR}/build"
mkdir -p "$OUTPUT_DIR"

# --- 1. Xcode Build ---
if [ "$SKIP_BUILD" = false ]; then
    log_info "Building $SCHEME ($CONFIGURATION)..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    XCODEBUILD_ARGS=(
        -project "$PROJECT"
        -scheme "$SCHEME"
        -configuration "$CONFIGURATION"
        -derivedDataPath "$BUILD_DIR"
        -destination "generic/platform=macOS"
        ARCHS=arm64
        MACOSX_DEPLOYMENT_TARGET=14.0
        MARKETING_VERSION="$VERSION"
    )

    if [ -n "$SIGNING_IDENTITY" ]; then
        log_info "Building with code signing identity: $SIGNING_IDENTITY"
        XCODEBUILD_ARGS+=(
            CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
            CODE_SIGNING_REQUIRED=YES
            CODE_SIGNING_ALLOWED=YES
        )
    else
        log_info "Building without signing (will ad-hoc sign during packaging)..."
        XCODEBUILD_ARGS+=(
            CODE_SIGN_IDENTITY=""
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGNING_ALLOWED=NO
        )
    fi

    xcodebuild build "${XCODEBUILD_ARGS[@]}" | xcbeautify 2>/dev/null || xcodebuild build "${XCODEBUILD_ARGS[@]}"
fi

# Locate the built .app
APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d -path "*/Products/${CONFIGURATION}/*" | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    # Fallback search in DerivedData if not in local build/
    APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "${APP_NAME}.app" -type d -path "*/Products/${CONFIGURATION}/*" 2>/dev/null | head -n 1 || true)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    log_error "Could not find built ${APP_NAME}.app. Please ensure build succeeded."
    exit 1
fi

log_success "Found application: $APP_PATH"

# --- 2. Ad-hoc Signing & Permission Verification ---
if [ -z "$SIGNING_IDENTITY" ]; then
    log_info "Applying ad-hoc code signature..."
    log_warn "Ad-hoc FinderSync builds may not appear in System Settings on macOS 26/27. Use --sign or an Apple Development identity for a usable installation."
    # Sign nested plugins first
    if [ -d "$APP_PATH/Contents/PlugIns/FinderSyncExt.appex" ]; then
        codesign --force --deep --sign - "$APP_PATH/Contents/PlugIns/FinderSyncExt.appex"
    fi
    codesign --force --deep --sign - "$APP_PATH"
fi

# --- 3. Package ZIP ---
ZIP_NAME="${DISPLAY_NAME}-v${VERSION}.zip"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"
log_info "Creating distribution ZIP: $ZIP_PATH..."
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | awk '{print $1}' > "${ZIP_PATH}.sha256"
log_success "Created $ZIP_NAME"

# --- 4. Package DMG ---
DMG_NAME="${DISPLAY_NAME}-v${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
rm -f "$DMG_PATH"

if command -v create-dmg >/dev/null 2>&1; then
    log_info "Packaging DMG with create-dmg..."
    DMG_STAGING="${PROJECT_DIR}/.dmg-staging"
    rm -rf "$DMG_STAGING"
    mkdir -p "$DMG_STAGING"
    ditto "$APP_PATH" "$DMG_STAGING/${DISPLAY_NAME}.app"

    create-dmg \
        --volname "$DISPLAY_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 110 \
        --icon "${DISPLAY_NAME}.app" 160 190 \
        --hide-extension "${DISPLAY_NAME}.app" \
        --app-drop-link 440 190 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$DMG_STAGING/${DISPLAY_NAME}.app" || {
            log_warn "create-dmg failed, falling back to hdiutil..."
            rm -rf "$DMG_STAGING"
        }
    rm -rf "$DMG_STAGING"
fi

# Fallback to native hdiutil if create-dmg was not used or failed
if [ ! -f "$DMG_PATH" ]; then
    log_info "Packaging DMG with native hdiutil..."
    DMG_TEMP_DIR=$(mktemp -d /tmp/rclickx-dmg.XXXXXX)
    ditto "$APP_PATH" "$DMG_TEMP_DIR/${DISPLAY_NAME}.app"
    ln -s /Applications "$DMG_TEMP_DIR/Applications"

    hdiutil create \
        -volname "$DISPLAY_NAME" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    rm -rf "$DMG_TEMP_DIR"
fi

# Sign DMG if identity provided, else ad-hoc sign
if [ -n "$SIGNING_IDENTITY" ]; then
    log_info "Signing DMG with: $SIGNING_IDENTITY"
    codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
else
    codesign --force --sign - "$DMG_PATH" 2>/dev/null || true
fi

# Generate SHA256 checksum
shasum -a 256 "$DMG_PATH" | awk '{print $1}' > "${DMG_PATH}.sha256"

# Verify DMG
log_info "Verifying DMG integrity..."
hdiutil verify "$DMG_PATH"

log_success "=================================================="
log_success "Build & Packaging Complete!"
log_success "Artifacts generated in: $OUTPUT_DIR"
log_success "  DMG:    $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
log_success "  SHA256: $(cat "${DMG_PATH}.sha256")"
log_success "  ZIP:    $ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1))"
log_success "=================================================="
