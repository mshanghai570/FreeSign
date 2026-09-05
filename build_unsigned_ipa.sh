#!/bin/bash
# ============================================================
# FreeSign — Unsigned IPA Builder
# Usage: ./build_unsigned_ipa.sh [Debug|Release]
#
# Produces a correctly structured IPA:
#   Payload/
#     FreeSign.app/
#
# Compatible with AltStore, Sideloadly, TrollStore, SideStore.
# ============================================================

set -e

# Make the script location-independent (run from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIGURATION="${1:-Release}"
SCHEME="FreeSign"
SDK="iphoneos"
BUILD_DIR="$(pwd)/build"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
IPA_NAME="FreeSign_${CONFIGURATION}_${TIMESTAMP}.ipa"
IPA_PATH="$BUILD_DIR/$IPA_NAME"

# ── Colours ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step()  { echo -e "${CYAN}▸ $1${NC}"; }
ok()    { echo -e "${GREEN}✓ $1${NC}"; }
fail()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     FreeSign Unsigned IPA Builder    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo -e "  Configuration : ${YELLOW}${CONFIGURATION}${NC}"
echo ""

mkdir -p "$BUILD_DIR"

# ── 1. Build ────────────────────────────────────────────────
step "Building ${SCHEME} (${CONFIGURATION})…"
BUILD_LOG="$BUILD_DIR/build.log"
xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "generic/platform=iOS" \
    SYMROOT="$BUILD_DIR" \
    OBJROOT="$BUILD_DIR/Intermediates" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build 2>&1 | tee "$BUILD_LOG"

# Check if build succeeded
if grep -q "BUILD FAILED" "$BUILD_LOG" || grep -q "error:" "$BUILD_LOG"; then
    fail "Build failed — check $BUILD_LOG for details"
fi
ok "Build succeeded"

# Confirm the binary was actually built
APP_PATH=$(find "$BUILD_DIR" -path "*${CONFIGURATION}-${SDK}/${SCHEME}.app" -maxdepth 4 -type d | head -1)
[[ -z "$APP_PATH" ]] && fail "Could not find ${SCHEME}.app — did the build succeed?"
ok "App bundle: $APP_PATH"

# Find the actual binary name
BINARY_NAME=$(find "$APP_PATH" -type f -perm +111 | grep -v ".dylib" | grep -v ".framework" | head -1)
BINARY_NAME=$(basename "$BINARY_NAME")
if [ -z "$BINARY_NAME" ] || [ "$BINARY_NAME" = "$APP_PATH" ]; then
    # Fallback: use the scheme name or read from Info.plist
    BINARY_NAME=$(defaults read "$APP_PATH/Info.plist" CFBundleExecutable 2>/dev/null || echo "$SCHEME")
fi
ok "Binary name: $BINARY_NAME"

# ── 2. Remove any leftover code signature ───────────────────
step "Stripping code signatures…"
rm -rf "$APP_PATH/_CodeSignature"
# Strip embedded frameworks and the main binary (sideload tools must re-sign everything)
find "$APP_PATH" -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true
while IFS= read -r -d '' bin; do
    codesign --remove-signature "$bin" 2>/dev/null || true
done < <(find "$APP_PATH" -type f \( -perm +111 -o -name "*.dylib" \) -print0 2>/dev/null)
ok "Signatures removed"

# ── 3. Package into correct IPA structure ───────────────────
#   Payload/
#     FreeSign.app/
step "Packaging IPA…"
STAGING=$(mktemp -d)
PAYLOAD_DIR="$STAGING/Payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

# Zip from inside the staging dir so the zip root is Payload/
(
  cd "$STAGING"
  ditto -c -k --sequesterRsrc --keepParent "Payload" "$IPA_PATH"
)
rm -rf "$STAGING"
ok "IPA created: $IPA_NAME"

# ── 4. Verify structure ─────────────────────────────────────
step "Verifying IPA structure…"
VERIFY_TMP=$(mktemp -d)
unzip -q "$IPA_PATH" -d "$VERIFY_TMP"

# Must have Payload/FreeSign.app
if [[ ! -d "$VERIFY_TMP/Payload/${SCHEME}.app" ]]; then
    rm -rf "$VERIFY_TMP"
    fail "Bad IPA structure — Payload/${SCHEME}.app not found"
fi
ok "Payload/${SCHEME}.app present"

# Must NOT be signed
if [[ -d "$VERIFY_TMP/Payload/${SCHEME}.app/_CodeSignature" ]]; then
    rm -rf "$VERIFY_TMP"
    fail "App is signed — unexpected _CodeSignature found"
fi
OPENSSL_BIN="$VERIFY_TMP/Payload/${SCHEME}.app/Frameworks/OpenSSL.framework/OpenSSL"
if [[ -f "$OPENSSL_BIN" ]] && codesign -dv "$OPENSSL_BIN" 2>/dev/null; then
    rm -rf "$VERIFY_TMP"
    fail "OpenSSL.framework is still signed — sideload resign may fail"
fi
ok "No code signature (unsigned)"

# Binary must exist - use the actual binary name we found
BINARY="$VERIFY_TMP/Payload/${SCHEME}.app/$BINARY_NAME"
if [[ ! -f "$BINARY" ]]; then
    rm -rf "$VERIFY_TMP"
    fail "Main binary not found inside app bundle at $BINARY"
fi
ok "Main binary present: $BINARY_NAME"

rm -rf "$VERIFY_TMP"

# ── 5. Summary ──────────────────────────────────────────────
IPA_SIZE=$(du -sh "$IPA_PATH" | cut -f1)
echo ""
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Build Complete            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo -e "  File : ${YELLOW}${IPA_PATH}${NC}"
echo -e "  Size : ${YELLOW}${IPA_SIZE}${NC}"
echo ""
echo -e "${CYAN}Sideload with:${NC}"
echo -e "  • ${YELLOW}TrollStore${NC}   — Open IPA in Files, share to TrollStore"
echo -e "  • ${YELLOW}SideStore${NC}    — Import via Wi-Fi sync or AltServer"
echo -e "  • ${YELLOW}Sideloadly${NC}   — Drag IPA onto Sideloadly on Mac/PC"
echo -e "  • ${YELLOW}AltStore${NC}     — My Apps → + → select IPA"
echo ""
