import SwiftUI

enum AppTab: String, CaseIterable, Codable {
    case library, sources, apps, files, settings
    
    var title: String {
        switch self {
        case .library:      return "Library"
        case .sources:      return "Sources"
        case .apps:         return "Apps"
        case .files:        return "Files"
        case .settings:     return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .library:      return "square.on.square"
        case .sources:      return "tray.and.arrow.down"
        case .apps:         return "square.grid.2x2"
        case .files:        return "folder"
        case .settings:     return "gearshape"
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var fileImporter = FileImporter.shared
    /// Show UIKit appearance helper once on load
    @State private var hasAppliedAppearance = false
    /// Honors the "Default Tab" setting in App Settings
    @State private var selectedTab: AppTab = Settings.shared.defaultTab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { LibraryView() }
                .tabItem { Label(AppTab.library.title, systemImage: AppTab.library.icon) }
                .tag(AppTab.library)
            
            NavigationStack { SourcesView() }
                .tabItem { Label(AppTab.sources.title, systemImage: AppTab.sources.icon) }
                .tag(AppTab.sources)
            
            NavigationStack { AppsView() }
                .tabItem { Label(AppTab.apps.title, systemImage: AppTab.apps.icon) }
                .tag(AppTab.apps)
            
            NavigationStack { FilesView() }
                .tabItem { Label(AppTab.files.title, systemImage: AppTab.files.icon) }
                .tag(AppTab.files)
            
            NavigationStack { SettingsView() }
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .tint(theme.accentColor)
        .preferredColorScheme(.dark)
        .background(TabBarAppearance().opacity(0))
        .background(NavBarAppearance().opacity(0))
        .background(theme.backgroundView)
        .withFileDrop()
        .sheet(isPresented: Binding(
            get: { fileImporter.currentFileURL != nil },
            set: { if !$0 { fileImporter.currentFileURL = nil } }
        )) {
            if let url = fileImporter.currentFileURL {
                FileImportProgressView(url: url)
            }
        }
    }
}
