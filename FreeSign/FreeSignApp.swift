//
//  FreeSignApp.swift
//  FreeSign
//
//  Created by Michael Shingara on 7/30/26.
//

import SwiftUI

@main
struct FreeSignApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Register custom fonts first so theme-dependent rendering can use them
        FontRegistration.registerFonts()
        
        // Apply theme after fonts
        ThemeManager.shared.applyTheme()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// AppDelegate for handling file imports and other UIKit functionality
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Apply UIKit appearance settings
        TabBarAppearance.apply()
        NavBarAppearance.apply()
        return true
    }
    
    // Handle file imports from Files app.
    // Must copy synchronously — the sandbox extension is only guaranteed valid
    // during this callback. FileImporter dedupes against SwiftUI's onOpenURL.
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return FileImporter.shared.handleFileURL(url)
    }
    
    // Handle universal links and custom URL schemes
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == "NSUserActivityTypeBrowsingWeb",
           let url = userActivity.webpageURL {
            return FileImporter.shared.handleFileURL(url)
        }
        return false
    }
}