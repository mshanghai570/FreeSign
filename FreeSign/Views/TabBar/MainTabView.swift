import SwiftUI

enum AppTab: String, CaseIterable, Codable {
    case library, sources, apps, files, settings

    var title: String {
        switch self {
        case .library: return "Library"
        case .sources: return "Sources"
        case .apps: return "Apps"
        case .files: return "Files"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .library: return "square.on.square"
        case .sources: return "tray.and.arrow.down"
        case .apps: return "square.grid.2x2"
        case .files: return "folder"
        case .settings: return "gearshape"
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var fileImporter = FileImporter.shared

    /// Honors the Default Tab setting in App Settings.
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

            FilesView()
                .tabItem { Label(AppTab.files.title, systemImage: AppTab.files.icon) }
                .tag(AppTab.files)

            NavigationStack { SettingsView() }
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .tint(theme.accentColor)
        .preferredColorScheme(.dark)
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
        .sheet(isPresented: Binding(
            get: { fileImporter.pendingCertificateURL != nil },
            set: { if !$0 { fileImporter.cancelPendingCertificateImport() } }
        )) {
            if let url = fileImporter.pendingCertificateURL {
                P12PasswordEntryView(
                    fileName: fileImporter.pendingCertificateFileName.isEmpty
                        ? url.lastPathComponent
                        : fileImporter.pendingCertificateFileName,
                    onCancel: { fileImporter.cancelPendingCertificateImport() },
                    onImport: { password in
                        fileImporter.importCertificate(fromLocalURL: url, password: password)
                    }
                )
            }
        }
        .alert("Certificate Import Failed", isPresented: Binding(
            get: { fileImporter.lastImportError != nil && fileImporter.currentFileURL == nil },
            set: { if !$0 { fileImporter.lastImportError = nil } }
        )) {
            Button("OK", role: .cancel) { fileImporter.lastImportError = nil }
        } message: {
            Text(fileImporter.lastImportError ?? "Unknown certificate import error.")
        }
    }
}
