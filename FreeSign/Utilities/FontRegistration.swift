import UIKit
import CoreText

struct FontRegistration {
    static func registerFonts() {
        // Font registration must not crash the app on launch,
        // especially for unsigned/sideloaded builds where font
        // access can behave differently.
        registerIBMPlexSansFonts()
    }
}

/// Registers IBM Plex Sans fonts from the app bundle so they're available
/// for use with `Font.custom(_:size:)` in SwiftUI.
private func registerIBMPlexSansFonts() {
    let fontNames = [
        "IBMPlexSans-Bold",
        "IBMPlexSans-BoldItalic",
        "IBMPlexSans-ExtraLight",
        "IBMPlexSans-ExtraLightItalic",
        "IBMPlexSans-Italic",
        "IBMPlexSans-Light",
        "IBMPlexSans-LightItalic",
        "IBMPlexSans-Medium",
        "IBMPlexSans-MediumItalic",
        "IBMPlexSans-Regular",
        "IBMPlexSans-SemiBold",
        "IBMPlexSans-SemiBoldItalic",
        "IBMPlexSans-Thin",
        "IBMPlexSans-ThinItalic",
    ]
    
    let bundle = Bundle.main
    var urls: [CFURL] = []
    
    for name in fontNames {
        let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "font")
            ?? bundle.url(forResource: name, withExtension: "ttf")
        guard let url else {
            print("⚠️ Font file not found: \(name).ttf")
            continue
        }
        urls.append(url as CFURL)
    }
    
    guard !urls.isEmpty else {
        print("⚠️ No IBM Plex Sans font files found to register.")
        return
    }
    
    var registeredCount = 0
    for url in urls {
        var cfError: Unmanaged<CFError>?
        let result = CTFontManagerRegisterFontsForURL(url, .process, &cfError)
        if result {
            registeredCount += 1
        } else if let error = cfError?.takeRetainedValue() {
            print("⚠️ Failed to register \((url as URL).lastPathComponent): \(error)")
        }
    }
    print("✅ Registered \(registeredCount)/\(urls.count) IBM Plex Sans fonts.")
}

// Compatibility wrapper so existing callers still work without changing call sites.
private func registerIBMPlexSansFontsCompat() {
    registerIBMPlexSansFonts()
}
