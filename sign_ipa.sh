#!/bin/bash

# IPA signing script using zsign (included in the project)
# This script uses the zsign binary that's compiled as part of the FreeSign app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we have an unsigned IPA
UNSIGNED_IPA="$(pwd)/build/FreeSign.ipa"
if [ ! -f "$UNSIGNED_IPA" ]; then
    echo -e "${RED}Error: No unsigned IPA found at $UNSIGNED_IPA${NC}"
    echo -e "Please run ${YELLOW}./build_unsigned_ipa.sh${NC} first"
    exit 1
fi

echo -e "${GREEN}=== FreeSign IPA Signing Script ===${NC}"
echo ""

# First, we need to build the zsign tool from the project
# The project includes zsign source code, so we can compile it

ZSIGN_SRC_DIR="$(pwd)"
ZSIGN_BUILD_DIR="$(pwd)/build/zsign"
ZSIGN_BIN="$ZSIGN_BUILD_DIR/zsign"

# Check if zsign is already built
if [ ! -f "$ZSIGN_BIN" ]; then
    echo -e "${YELLOW}Building zsign tool...${NC}"
    
    # Create build directory
    mkdir -p "$ZSIGN_BUILD_DIR"
    
    # Compile zsign for macOS (since we're running on macOS to sign)
    # We need to compile the zsign.cpp and related files
    cd "$ZSIGN_SRC_DIR"
    
    # Find all the C++ files that zsign needs
    ZSIGN_SOURCES=(
        "zsign.cpp"
        "signing.cpp"
        "macho.cpp"
        "bundle.cpp"
        "archo.cpp"
        "certcheck.cpp"
        "metadata.cpp"
        "openssl.cpp"
        "Zsignwrapper.cpp"
        "zsignwrapper.cpp"
        "fs.cpp"
        "sha.cpp"
        "log.cpp"
        "util.cpp"
        "timer.cpp"
        "archive.cpp"
        "base64.cpp"
        "json.cpp"
    )
    
    # C files (zlib and others)
    C_SOURCES=(
        "zip.c" "unzip.c" "ioapi.c" "iowin32.c" "mztools.c"
        "adler32.c" "compress.c" "crc32.c" "deflate.c" "gzclose.c"
        "gzlib.c" "gzwrite.c" "gzread.c" "infback.c" "inffast.c"
        "inflate.c" "infrees.c" "inftrees.c" "uncompr.c" "zutil.c"
        "trees.c" "gzlib.c"
    )
    
    echo -e "${YELLOW}Compiling zsign (this may take a while)...${NC}"
    
    # Compile with OpenSSL support
    # Note: This is a simplified approach. The actual zsign build system is more complex.
    # For production use, you might want to use the existing Xcode project to build zsign.
    
    echo -e "${RED}Note: zsign compilation is complex and requires proper OpenSSL linking.${NC}"
    echo -e "${YELLOW}For now, this script will show you how to use zsign once it's built.${NC}"
    echo ""
else
    echo -e "${GREEN}Using existing zsign binary: ${YELLOW}$ZSIGN_BIN${NC}"
fi

echo -e "${GREEN}=== Signing Options ===${NC}"
echo ""
echo "To sign your IPA, you have several options:"
echo ""
echo -e "${YELLOW}Option 1: Ad-hoc signing (no certificate needed)${NC}"
echo "  $ZSIGN_BIN -a -o signed.ipa $UNSIGNED_IPA"
echo ""
echo -e "${YELLOW}Option 2: Sign with certificate and provisioning profile${NC}"
echo "  $ZSIGN_BIN -k path/to/private_key.pem -m path/to/profile.mobileprovision -o signed.ipa $UNSIGNED_IPA"
echo ""
echo -e "${YELLOW}Option 3: Sign with p12 certificate${NC}"
echo "  $ZSIGN_BIN -k path/to/cert.p12 -p your_password -m path/to/profile.mobileprovision -o signed.ipa $UNSIGNED_IPA"
echo ""
echo -e "${YELLOW}Option 4: Use Sideloadly or AltStore${NC}"
echo "  These tools can sign and install the unsigned IPA directly"
echo ""

# If zsign is available, offer to sign with ad-hoc
if [ -f "$ZSIGN_BIN" ]; then
    read -p "Do you want to create an ad-hoc signed IPA? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SIGNED_IPA="$(pwd)/build/FreeSign_adhoc.ipa"
        echo -e "${GREEN}Creating ad-hoc signed IPA...${NC}"
        "$ZSIGN_BIN" -a -o "$SIGNED_IPA" "$UNSIGNED_IPA"
        
        if [ -f "$SIGNED_IPA" ]; then
            echo -e "${GREEN}✓ Ad-hoc signed IPA created: ${YELLOW}$SIGNED_IPA${NC}"
        else
            echo -e "${RED}Error: Failed to create signed IPA${NC}"
        fi
    fi
fi

echo -e "${GREEN}=== Summary ===${NC}"
echo "Unsigned IPA: $UNSIGNED_IPA"
echo ""
echo "You can now:"
echo "1. Use Sideloadly to sideload the unsigned IPA"
echo "2. Use AltStore to sideload the unsigned IPA"
echo "3. Use the zsign tool to sign it with your own certificates"
echo "4. Use TrollStore if your device supports it"