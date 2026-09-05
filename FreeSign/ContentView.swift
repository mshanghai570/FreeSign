//
//  ContentView.swift
//  FreeSign
//
//  Created by Michael Shingara on 7/30/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var fileImporter = FileImporter.shared
    @ObservedObject private var dataManager = AppDataManager.shared
    
    var body: some View {
        MainTabView()
            .environmentObject(theme)
            .environmentObject(fileImporter)
            .environmentObject(dataManager)
            .onOpenURL { url in
                // Handle URLs from Files app and other sources
                handleIncomingURL(url)
            }
            .onContinueUserActivity("NSUserActivityTypeBrowsingWeb") { userActivity in
                if let url = userActivity.webpageURL {
                    handleIncomingURL(url)
                }
            }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle file URLs from Files app.
        // Synchronous call — FileImporter dedupes against the AppDelegate callback.
        if url.isFileURL {
            FileImporter.shared.handleFileURL(url)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(FileImporter.shared)
        .environmentObject(AppDataManager.shared)
}