import SwiftUI
import UniformTypeIdentifiers

// MARK: - SourcesView

struct SourcesView: View {
    @StateObject private var dataManager = AppDataManager.shared
    @State private var showFilePicker   = false
    @State private var showAddSource    = false
    @State private var searchText       = ""
    @State private var isImporting      = false
    @State private var importProgress   = ""
    @State private var importError: String?
    @State private var showImportError  = false
    @State private var selectedAppForProperties: AppInfo?
    @State private var showBundleBrowser = false
    @State private var extractedApp: BundleEditor.ExtractedApp?
    @State private var selectedTab: SourcesTab = .repositories
    
    enum SourcesTab: String, CaseIterable {
        case repositories = "Repositories"
        case allApps = "All Apps"
        
        var icon: String {
            switch self {
            case .repositories: return "globe"
            case .allApps: return "square.grid.2x2"
            }
        }
    }
    
    var allSourceApps: [SourceApp] {
        var apps: [SourceApp] = []
        for source in dataManager.sources {
            apps.append(contentsOf: source.apps)
        }
        return apps
    }
    
    var filteredSourceApps: [SourceApp] {
        var apps = allSourceApps
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.developerName.localizedCaseInsensitiveContains(searchText) ||
                ($0.localizedDescription ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return apps
    }
    
    var filteredImportedApps: [AppInfo] {
        let apps = dataManager.importedApps
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Segmented Control
                    Picker("", selection: $selectedTab) {
                        ForEach(SourcesTab.allCases, id: \.self) { tab in
                            Label(tab.rawValue, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    
                    if selectedTab == .repositories {
                        if !dataManager.sources.isEmpty {
                            sourcesSection
                        } else {
                            emptySourcesState
                        }
                    } else {
                        if !filteredSourceApps.isEmpty {
                            allSourceAppsSection
                        } else {
                            emptyAllSourceAppsState
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .refreshable { await refreshAllSources() }

            if isImporting {
                LoadingOverlay(message: importProgress.isEmpty ? "Analyzing IPA…" : importProgress)
            }
        }
        .appNavigationTitle("Sources")
        .appNavigationStyle()
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: selectedTab == .repositories ? "Search repositories…" : "Search all source apps…")
        .toolbar { toolbarContent }
        // IPA file picker — uses declared UTType so the picker filters correctly
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: ipaContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFilePicker(result: result)
        }
        .sheet(isPresented: $showAddSource) { AddRepositoriesView() }
        .sheet(item: $selectedAppForProperties) { app in
            NavigationStack {
                AppPropertiesView(app: app)
            }
        }
        .sheet(isPresented: $showBundleBrowser) {
            if let extractedApp {
                NavigationStack {
                    BundleBrowserView(extracted: extractedApp)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showBundleBrowser = false }
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                }
            }
        }
        .alert("Import Failed", isPresented: $showImportError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    // MARK: - UTTypes

    // Use specific UTTypes for IPA files to ensure proper file selection
    private var ipaContentTypes: [UTType] {
        // UTTypes are optional; never force-unwrap (crash on some OS versions).
        [
            UTType("com.apple.itunes.ipa"),
            UTType("public.zip-archive"),
            UTType(filenameExtension: "ipa"),
            .data
        ].compactMap { $0 }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showFilePicker = true
                } label: {
                    Label("Import IPA from Files", systemImage: "doc.badge.plus")
                }
                Button {
                    Task { await refreshAllSources() }
                } label: {
                    Label("Refresh All Sources", systemImage: "arrow.clockwise")
                }
                Button {
                    showAddSource = true
                } label: {
                    Label("Add Source URL", systemImage: "plus.circle")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            TabAssistantButton(sourceView: "Sources", summary: sourcesAssistantSummary)
        }
    }

    // MARK: - Assistant

    /// Summary of what is currently on the Sources tab, for the Lab Assistant.
    private var sourcesAssistantSummary: String {
        var appCount = 0
        for source in dataManager.sources { appCount += source.apps.count }
        return "Sources tab: \(dataManager.sources.count) repository/repositories containing "
             + "\(appCount) app(s)."
    }

    // MARK: - Sources Section

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Repositories")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                StatusBadge(text: "\(dataManager.sources.count)", color: AppColors.accent)
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 8) {
                ForEach(dataManager.sources) { source in
                    NavigationLink(destination: SourceBrowserView(source: source)) {
                        SourceCard(source: source) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dataManager.removeSource(source)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Imported Apps Section

    private var importedAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Imported IPAs")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                if !dataManager.importedApps.isEmpty {
                    StatusBadge(
                        text: "\(dataManager.importedApps.count)",
                        color: AppColors.accent
                    )
                }
            }
            .padding(.horizontal, 20)

            if filteredImportedApps.isEmpty {
                emptyImportedState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredImportedApps) { app in
                        NavigationLink(destination: SigningView(app: app)) {
                            ImportedAppRow(app: app)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button {
                                selectedAppForProperties = app
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
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 16)
                .animation(.easeOut(duration: 0.2), value: filteredImportedApps.count)
            }
        }
    }

    private var emptyImportedState: some View {
        EmptyStateView(
            icon: "tray.and.arrow.down",
            title: "No IPAs Imported",
            message: "Import an IPA from the Files app, or browse\na repository to download one.",
            actionTitle: "Import IPA",
            action: { showFilePicker = true }
        )
    }

// MARK: - All Source Apps Section

    private var allSourceAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All Source Apps")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
                if !filteredSourceApps.isEmpty {
                    StatusBadge(
                        text: "\(filteredSourceApps.count)",
                        color: AppColors.accent
                    )
                }
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 8) {
                ForEach(filteredSourceApps) { app in
                    if let source = findSourceForApp(app) {
                        SourceAppRow(app: app, source: source)
                    }
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeOut(duration: 0.2), value: filteredSourceApps.count)
        }
    }

    private func findSourceForApp(_ app: SourceApp) -> Source? {
        return dataManager.sources.first { $0.apps.contains { $0.id == app.id } }
    }

    private var emptyAllSourceAppsState: some View {
        EmptyStateView(
            icon: "square.grid.2x2",
            title: "No Source Apps",
            message: "Add a repository URL and refresh it to\nbrowse available apps.",
            actionTitle: "Add Source",
            action: { showAddSource = true }
        )
    }

    private var emptySourcesState: some View {
        EmptyStateView(
            icon: "globe",
            title: "No Repositories",
            message: "Add a repository URL to start browsing\napps from external sources.",
            actionTitle: "Add Source",
            action: { showAddSource = true }
        )
    }

    // MARK: - File Picker Handler    // MARK: - File Picker Handler

    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            // User cancelled returns an error; distinguish via description
            if (error as NSError).code != NSUserCancelledError {
                presentError("Could not open the file picker: \(error.localizedDescription)")
            }

        case .success(let urls):
            guard let url = urls.first else { return }
            
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            
            guard url.pathExtension.lowercased() == "ipa" else {
                presentError("Selected file is not an IPA")
                return
            }
            
            do {
                let localURL = try StorageManager.shared.storeIPA(from: url)
                importIPA(fromLocalURL: localURL)
            } catch {
                presentError("Failed to copy selected file to sandbox: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - IPA Import

    private func importIPA(fromLocalURL url: URL) {
        isImporting   = true
        importProgress = "Analyzing bundle…"

        Task.detached(priority: .userInitiated) {
            do {
                // ── Step 1: Analyze the IPA (extract, parse, icon) ───────────────
                let meta = try IPAAnalyzer.shared.analyze(ipaPath: url.path)

                // ── Step 2: Cache the icon ────────────────────────────────────────
                let appID = UUID()
                if let iconData = meta.iconData {
                    StorageManager.shared.storeIcon(iconData, appID: appID)
                }
                let iconPath = meta.iconData != nil
                    ? StorageManager.shared.iconsURL
                        .appendingPathComponent("\(appID.uuidString).png").path
                    : nil

                // ── Step 3: Build the AppInfo model ───────────────────────────────
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

                // ── Step 4: Persist ───────────────────────────────────────────────
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
                    presentError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Source Refresh

    /// Re-fetch every repository and persist the updated app lists.
    private func refreshAllSources() async {
        let urls = dataManager.sources.map { $0.url }
        guard !urls.isEmpty else { return }

        let results = await SourceFetcher.shared.fetchSources(urlStrings: urls)
        for result in results {
            if let updated = result.source {
                dataManager.updateSource(byURL: result.url, with: updated)
            }
        }
    }

    private func presentError(_ message: String) {
        importError    = message
        showImportError = true
    }
    
    private func browseIPA(app: AppInfo) {
        Task.detached(priority: .userInitiated) {
            do {
                let extractedApp = try BundleEditor.shared.extractIPA(app.ipaPath)
                
                await MainActor.run {
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
}

// MARK: - Import Errors



// MARK: - Source Card

struct SourceCard: View {
    let source: Source
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AccentIconBackground(systemName: "globe", size: 44, iconSize: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                Text(source.url)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !source.apps.isEmpty {
                        StatusBadge(text: "\(source.apps.count) apps", color: AppColors.accent)
                    } else {
                        Text("Not yet fetched")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.disabledText)
                    }
                    if source.lastFetched != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.success)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.disabledText)
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Imported App Row
// ImportedAppRow is now defined in Library/ImportedAppRow.swift for reuse across the app

// AddSourceView is superseded by AddRepositoriesView in AddRepositoriesView.swift.

#Preview {
    NavigationStack { SourcesView() }
}
