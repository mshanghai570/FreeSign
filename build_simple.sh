#!/bin/bash

# Simple build script for FreeSign
cd /Users/michaelshingara/Documents/FreeSigniOS/FreeSign

echo "Cleaning project..."
xcodebuild clean -scheme FreeSign -configuration Release

echo "Building project..."
xcodebuild -scheme FreeSign -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build succeeded!"
    
    # Find the app bundle
    APP_PATH=$(find build -name "FreeSign.app" -path "*Release-iphoneos*" | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "Found app at: $APP_PATH"
        
        # Create IPA
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        IPA_NAME="FreeSign_unsigned_${TIMESTAMP}.ipa"
        
        echo "Creating IPA..."
        mkdir -p Payload
        cp -R "$APP_PATH" Payload/
        zip -r "$IPA_NAME" Payload/
        rm -rf Payload
        
        echo "IPA created: $IPA_NAME"
    else
        echo "Error: Could not find FreeSign.app in build directory"
    fi
else
    echo "Build failed!"
fi