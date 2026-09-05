import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var dataManager = AppDataManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var searchText = ""
    @State private var selectedTab: LibraryTab = .apps
    @State private var showBundleBrowser = false
    @State private var extractedApp: BundleEditor.ExtractedApp?
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importProgress = ""
    @State private var selectedAppForProperties: AppInfo?
    @State private var importError: String?
    @State private var showImportError = false

    // Use specific UTTypes for IPA files to ensure proper file selection
    private var ipaContentTypes: [UTType] {
        // Never force-unwrap UTTypes: identifiers such as "com.apple.itunes.ipa"
        // may not resolve on every OS version, and an unwrap crash would take
        // down the whole tab. compactMap drops unresolved identifiers.
        [
            UTType("com.apple.itunes.ipa"),
            UTType("public.zip-archive"),
            UTType(filenameExtension: "ipa"),
            .data
        ].compactMap { $0 }
    }
    
    enum LibraryTab {
        case apps
        case imported
        case signed
    }
    
    // Filter imported apps based on search text
    var filteredImportedApps: [AppInfo] {
        let apps = dataManager.importedApps
        if searchText.isEmpty { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText) ||
            $0.version.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Filter signed apps based on search text
    var filteredSignedApps: [InstalledApp] {
        let apps = dataManager.installedApps
        if searchText.isEmpty { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleID.localizedCaseInsensitiveContains(searchText) ||
            app.version.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Every app from every source, deduplicated by bundle ID (first source wins),
    // sorted by name. This is the app library the user expects to find here.
    private var allSourceApps: [(source: Source, app: SourceApp)] {
        var seen = Set<String>()
        var result: [(source: Source, app: SourceApp)] = []
        for source in dataManager.sources {
            for app in source.apps {
                let key = app.bundleID.isEmpty ? app.id.uuidString : app.bundleID
                if seen.insert(key).inserted {
                    result.append((source, app))
                }
            }
        }
        return result.sorted {
            $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
        }
    }

    // Filter repository apps based on search text
    private var filteredSourceApps: [(source: Source, app: SourceApp)] {
        let all = allSourceApps
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.app.name.localizedCaseInsensitiveContains(searchText) ||
            $0.app.developerName.localizedCaseInsensitiveContains(searchText) ||
            ($0.app.localizedDescription ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented control for switching between apps from repositories,
            // imported IPAs, and signed/installed apps
            Picker("Library Section", selection: $selectedTab) {
                Text("Apps").tag(LibraryTab.apps)
                Text("Imported").tag(LibraryTab.imported)
                Text("Signed").tag(LibraryTab.signed)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Content based on selected tab
            switch selectedTab {
            case .apps:     sourceAppsSection
            case .imported: importedIPAsSection
            case .signed:   signedAppsSection
            }
        }
        .appNavigationTitle("Library")
        .appNavigationStyle()
        .searchable(text: $searchText, 
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search apps...")
        .background(theme.backgroundView)
        .sheet(isPresented: $showBundleBrowser) {
            if let extractedApp {
                NavigationStack {
                    BundleBrowserView(extracted: extractedApp)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showBundleBrowser = false }
                                    .foregroundColor(theme.accentColor)
                            }
                        }
                }
            }
        }
        .sheet(item: $selectedAppForProperties) { app in
            NavigationStack {
                AppPropertiesView(app: app)
            }
        }
        .alert("Import Failed", isPresented: $showImportError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in Text(msg) }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: ipaContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFilePicker(result: result)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                TabAssistantButton(
                    sourceView: "Library",
                    summary: libraryAssistantSummary,
                    details: libraryAssistantDetails
                )
            }
        }
        .overlay {
            if isImporting {
                LoadingOverlay(message: importProgress.isEmpty ? "Importing IPA…" : importProgress)
            }
        }
    }

    // MARK: - Assistant

    /// Summary of what is currently on the Library tab, for the Lab Assistant.
    private var libraryAssistantSummary: String {
        let imported = dataManager.importedApps.count
        let signed = dataManager.installedApps.count
        let sourceApps = allSourceApps.count
        let certs = dataManager.certificates.count
        return "Library tab: \(imported) imported app(s), \(signed) signed app(s), "
             + "\(sourceApps) apps from \(dataManager.sources.count) repositories, "
             + "\(certs) certificate(s)."
    }

    /// A bounded snapshot of the library state currently visible to the user.
    private var libraryAssistantDetails: [String: Any] {
        let section: String
        switch selectedTab {
        case .apps: section = "Repository apps"
        case .imported: section = "Imported IPAs"
        case .signed: section = "Signed apps"
        }
        return [
            "selectedSection": section,
            "searchQuery": searchText,
            "visibleRepositoryApps": filteredSourceApps.prefix(20).map { $0.app.name },
            "visibleImportedApps": filteredImportedApps.prefix(20).map { "\($0.name) (\($0.bundleID))" },
            "visibleSignedApps": filteredSignedApps.prefix(20).map { "\($0.name) (\($0.bundleID))" },
            "availableCertificates": dataManager.certificates.prefix(10).map { $0.name }
        ]
    }
    
    // MARK: - Imported IPAs Section
    
    private var importedIPAsSection: some View {
        Group {
            if filteredImportedApps.isEmpty {
                EmptyStateView(
                    icon: "tray.and.arrow.down",
                    title: "No IPAs Imported",
                    message: "Import an IPA from the Files app or download one from a repository.",
                    actionTitle: "Browse Sources",
                    action: navigateToSources
                )
            } else {
                importedAppsList
            }
        }
    }
    
    private var importedAppsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredImportedApps) { app in
                    NavigationLink(destination: SigningView(app: app)) {
                        ImportedAppRow(app: app)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dataManager.removeImportedApp(app)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            // View app properties (Feather feature)
                            showProperties(app: app)
                        } label: {
                            Label("Properties", systemImage: "doc.text.magnifyingglass")
                        }
                        
                        Button {
                            // Browse IPA contents
                            browseIPA(app: app)
                        } label: {
                            Label("Browse Contents", systemImage: "folder")
                        }
                        
                        Button {
                            // Share IPA file
                            shareIPA(app: app)
                        } label: {
                            Label("Share IPA", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dataManager.removeImportedApp(app)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            // Refresh the list
        }
    }
    
    // MARK: - Signed Apps Section
    
    private var signedAppsSection: some View {
        Group {
            if filteredSignedApps.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield",
                    title: "No Signed Apps",
                    message: "Apps you sign will appear here. Import an IPA and sign it to get started.",
                    actionTitle: "Import IPA",
                    action: navigateToSources
                )
            } else {
                signedAppsList
            }
        }
    }
    
    private var signedAppsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSignedApps) { app in
                    InstalledAppCard(app: app)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteSignedApp(app)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                // Re-sign the app
                                // For now, just navigate to signing view with the original app info
                                if let importedApp = dataManager.importedApps.first(where: { $0.id == app.id }) {
                                    // This would need to be implemented based on your app flow
                                }
                            } label: {
                                Label("Re-sign", systemImage: "arrow.clockwise")
                            }
                            
                            Button(role: .destructive) {
                                deleteSignedApp(app)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            // Refresh the list
        }
    }
    
    // MARK: - Repository Apps Section
    
    private var sourceAppsSection: some View {
        Group {
            if filteredSourceApps.isEmpty {
                EmptyStateView(
                    icon: "square.grid.2x2",
                    title: searchText.isEmpty ? "No Apps in Library" : "No Results",
                    message: searchText.isEmpty
                        ? "Add repositories in the Sources tab, then pull to\nrefresh to load their apps here. Tap the download\nbutton to import an app's IPA."
                        : "No apps match \"\(searchText)\".",
                    actionTitle: "Browse Sources",
                    action: navigateToSources
                )
            } else {
                sourceAppsList
            }
        }
    }
    
    private var sourceAppsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredSourceApps, id: \.app.id) { entry in
                    SourceAppRow(app: entry.app, source: entry.source)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await refreshSourceApps() }
    }
    
    private func refreshSourceApps() async {
        let urls = dataManager.sources.map { $0.url }
        guard !urls.isEmpty else { return }
        let results = await SourceFetcher.shared.fetchSources(urlStrings: urls)
        for result in results {
            if let updated = result.source {
                dataManager.updateSource(byURL: result.url, with: updated)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToSources() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 1 // Sources tab index
        }
    }
    
    private func showProperties(app: AppInfo) {
        selectedAppForProperties = app
    }
    
    private func browseIPA(app: AppInfo) {
        // Extract the IPA and open bundle browser
        Task.detached(priority: .userInitiated) {
            do {
                // Use BundleEditor to extract and get proper structure
                let extractedApp = try BundleEditor.shared.extractIPA(app.ipaPath)
                
                await MainActor.run {
                    // Show bundle browser
                    self.extractedApp = extractedApp
                    self.showBundleBrowser = true
                }
            } catch {
                await MainActor.run {
                    print("Failed to extract IPA: \(error)")
                }
            }
        }
    }
    
    private func shareIPA(app: AppInfo) {
        let url = URL(fileURLWithPath: app.ipaPath)
        let activityItems = [url]
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityVC, animated: true)
    }
    
    private func deleteSignedApp(_ app: InstalledApp) {
        withAnimation(.easeOut(duration: 0.2)) {
            if let signedPath = app.signedIPA {
                try? FileManager.default.removeItem(atPath: signedPath)
            }
            try? FileManager.default.removeItem(atPath: app.originalIPA)
            dataManager.removeInstalledApp(app)
        }
    }
    
    // MARK: - File Picker Handler
    
    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            // User cancelled returns an error; distinguish via description
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                print("File picker error: \(error.localizedDescription)")
            }
        
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            
            guard url.pathExtension.lowercased() == "ipa" else {
                showImportError("Please select a valid .ipa file.")
                return
            }
            
            do {
                let localURL = try StorageManager.shared.storeIPA(from: url)
                importIPA(fromLocalURL: localURL)
            } catch {
                showImportError("Failed to copy the selected file: \(error.localizedDescription)")
            }
        }
    }

    private func showImportError(_ msg: String) {
        importError = msg
        showImportError = true
    }
    
    // MARK: - IPA Import
    
    private func importIPA(fromLocalURL url: URL) {
        isImporting = true
        importProgress = "Analyzing bundle…"
        
        Task.detached(priority: .userInitiated) {
            do {
                // Step 1: Analyze the IPA
                let meta = try IPAAnalyzer.shared.analyze(ipaPath: url.path)
                
                // Step 2: Cache the icon
                let appID = UUID()
                if let iconData = meta.iconData {
                    StorageManager.shared.storeIcon(iconData, appID: appID)
                }
                let iconPath = meta.iconData != nil
                    ? StorageManager.shared.iconsURL
                        .appendingPathComponent(appID.uuidString + ".png").path
                    : nil
                
                // Step 3: Build the AppInfo model
                let app = AppInfo(
                    id:                 appID,
                    name:               meta.name,
                    bundleID:           meta.bundleID,
                    version:            meta.version,
                    buildNumber:        meta.buildNumber,
                    minOSVersion:       meta.minOSVersion,
                    ipaPath:            url.path,
                    iconPath:           iconPath,
                    fileSize:           meta.fileSize,
                    architectures:      meta.architectures,
                    embeddedFrameworks: meta.embeddedFrameworks,
                    isEncrypted:        meta.isEncrypted,
                    isSigned:           meta.isSigned,
                    isFavorite:         false,
                    tags:               [],
                    dateImported:       Date(),
                    sourceURL:          nil
                )
                
                // Step 4: Persist
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        AppDataManager.shared.addImportedApp(app)
                    }
                    isImporting = false
                }
                
            } catch {
                // Clean up copied sandbox file on failure
                try? FileManager.default.removeItem(at: url)
                
                await MainActor.run {
                    isImporting = false
                    print("Import failed: \(error.localizedDescription)")
                    showImportError("Failed to analyze IPA: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
}

// MARK: - Installed App Card

struct InstalledAppCard: View {
    let app: InstalledApp
    @StateObject private var dataManager = AppDataManager.shared
    
    var body: some View {
        HStack(spacing: 14) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface)
                    .frame(width: 52, height: 52)
                if let iconData = app.iconData, let uiImage = UIImage(data: iconData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .cornerRadius(14)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accent)
                }
            }
            
            // App info
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(app.bundleID)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Version & status
            VStack(alignment: .trailing, spacing: 4) {
                Text("v\(app.version)")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(app.isSigned ? AppColors.accent : AppColors.disabledText)
                        .frame(width: 6, height: 6)
                    Text(app.isSigned ? "Signed" : "Unsigned")
                        .font(AppFont.small)
                        .foregroundColor(app.isSigned ? AppColors.accent : AppColors.disabledText)
                }
            }
        }
        .appCard()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

#Preview {
    NavigationStack { LibraryView() }
}
