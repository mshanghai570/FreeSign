# FreeSign iOS Build Guide

This guide explains how to build and create unsigned IPA files for sideloading the FreeSign app.

## Prerequisites

- macOS with Xcode installed
- iOS device for sideloading (optional, for testing)
- Sideloading tool (AltStore, Sideloadly, TrollStore, etc.)

## Project Configuration

The project has been configured to **disable code signing** for the main target, which allows you to build unsigned IPA files that can be sideloaded using third-party tools.

### What was changed:
- `CODE_SIGN_STYLE = Manual`
- `CODE_SIGNING_REQUIRED = NO`
- `CODE_SIGNING_ALLOWED = NO`

This means Xcode will not attempt to sign the app during the build process.

## Building the App

### Option 1: Using the Build Script (Recommended)

```bash
# Make the script executable (first time only)
chmod +x build_unsigned_ipa.sh

# Build Release version for device
./build_unsigned_ipa.sh Release device

# Build Debug version for device  
./build_unsigned_ipa.sh Debug device

# Build for simulator (for testing)
./build_unsigned_ipa.sh Release simulator
```

The script will:
1. Build the app using Xcode
2. Create an unsigned IPA file in the `build/` directory
3. Verify that the IPA is unsigned
4. Display the IPA path and size

### Option 2: Manual Build with Xcode

1. Open `FreeSign.xcodeproj` in Xcode
2. Select your target device or "Any iOS Device"
3. Choose Product > Build (⌘B)
4. The unsigned app will be in:
   ```
   ~/Library/Developer/Xcode/DerivedData/FreeSign-*/Build/Products/Release-iphoneos/
   ```

### Option 3: Manual Build with xcodebuild

```bash
# Build Release version
xcodebuild -scheme FreeSign -configuration Release -sdk iphoneos build

# Build Debug version
xcodebuild -scheme FreeSign -configuration Debug -sdk iphoneos build
```

## Creating an IPA File

### Using the Build Script
The build script automatically creates an IPA file in the `build/` directory.

### Manual IPA Creation

```bash
# Navigate to the build directory
cd ~/Library/Developer/Xcode/DerivedData/FreeSign-*/Build/Products/Release-iphoneos/

# Create IPA from the app bundle
mkdir -p ~/Desktop/FreeSign_IPAs
ditto -c -k --sequesterRsrc --keepParent FreeSign.app ~/Desktop/FreeSign_IPAs/FreeSign.ipa
```

## Verifying the IPA is Unsigned

```bash
# Extract the IPA to a temporary directory
unzip -q FreeSign.ipa -d /tmp/ipa_check

# Check for code signatures (should not exist for main app)
find /tmp/ipa_check/FreeSign.app -name "*CodeSignature*" -o -name "*mobileprovision*"

# Check binary signature (should show "code object is not signed at all")
codesign -v /tmp/ipa_check/FreeSign.app/FreeSign
```

## Sideloading the IPA

### Option 1: Using Sideloadly (Recommended)

1. Download [Sideloadly](https://sideloadly.io/)
2. Connect your iOS device to your Mac
3. Open Sideloadly
4. Drag and drop the unsigned IPA file
5. Enter your Apple ID (free account works)
6. Click Start to sideload

### Option 2: Using AltStore

1. Install AltStore on your iOS device
2. Connect your device to your Mac
3. Open AltStore
4. Select the unsigned IPA file
5. Install to your device

### Option 3: Using TrollStore (Permanent Sideloading)

If your device supports TrollStore (iOS 14.0-15.4.1):
1. Install TrollStore using the appropriate exploit
2. Use TrollHelper to sign and install the IPA permanently

### Option 4: Manual Signing with zsign

The project includes the zsign source code, which can be used to sign IPAs:

```bash
# Ad-hoc signing (no certificate needed)
./zsign -a -o signed.ipa unsigned.ipa

# Sign with certificate and provisioning profile
./zsign -k private_key.pem -m profile.mobileprovision -o signed.ipa unsigned.ipa

# Sign with p12 certificate
./zsign -k cert.p12 -p password -m profile.mobileprovision -o signed.ipa unsigned.ipa
```

## Troubleshooting

### Build Errors

**Error: "Signing for FreeSign requires a development team"**
- Make sure you've applied the project changes (CODE_SIGN_STYLE = Manual, etc.)
- Clean the project: Product > Clean Build Folder (⇧⌘K)
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/`

**Error: "No signing certificate"**
- The project is configured to not require signing, so this shouldn't happen
- Make sure you're building the correct scheme (FreeSign, not FreeSignTests)

### IPA Issues

**IPA is signed when it shouldn't be**
- Check that CODE_SIGNING_REQUIRED = NO in the project settings
- Make sure you're building the Release configuration
- The OpenSSL.framework might have signatures, but the main app should be unsigned

**IPA won't install on device**
- Make sure you're using a compatible sideloading tool
- Try ad-hoc signing with zsign
- Check that your device iOS version matches the app's deployment target (18.2)

### Device Compatibility

The app targets iOS 18.2, so you need:
- iOS 18.2 or later on your device
- Xcode 15.2 or later (for iOS 18.2 SDK)

## Clean Build

To ensure a completely clean build:

```bash
# Clean Xcode build
xcodebuild clean

# Delete DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/FreeSign*

# Delete build directory
rm -rf build/

# Then rebuild
./build_unsigned_ipa.sh Release device
```

## Notes

- The unsigned IPA can be sideloaded using free Apple IDs (7-day limit) or paid developer accounts (1-year limit)
- For permanent sideloading, consider TrollStore if your device is compatible
- The app includes zsign functionality, which you can use to sign IPAs with your own certificates
- Always test on simulator first before sideloading to a device