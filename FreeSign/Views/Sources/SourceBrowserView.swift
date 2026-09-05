import SwiftUI

// MARK: - SourceBrowserView

/// Displays all apps fetched from a single repository source.
/// Supports search, category filtering, and one-tap IPA download + import.
struct SourceBrowserView: View {
    @ObservedObject var dataManager = AppDataManager.shared
    @State var source: Source

    @State private var searchText    = ""
    @State private var selectedCat: String? = nil
    @State private var isRefreshing  = false
    @State private var refreshError: String?
    @State private var showError     = false

    var filteredApps: [SourceApp] {
        var apps = source.apps
        if let cat = selectedCat { apps = apps.filter { $0.category == cat } }
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.developerName.localizedCaseInsensitiveContains(searchText) ||
                ($0.localizedDescription ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return apps
    }

    var categories: [String] {
        Array(Set(source.apps.compactMap { $0.category })).sorted()
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    sourceHeader
                    if !categories.isEmpty { categoryFilter }
                    appList
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)

            if isRefreshing {
                LoadingOverlay(message: "Refreshing source…")
            }
        }
        .appNavigationTitle(source.name)
        .appNavigationStyle()
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search \(source.apps.count) apps…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.accent)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing
                                   ? .linear(duration: 1).repeatForever(autoreverses: false)
                                   : .default,
                                   value: isRefreshing)
                }
                .disabled(isRefreshing)
            }
        }
        .alert("Refresh Failed", isPresented: $showError, presenting: refreshError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in Text(msg) }
    }

    // MARK: - Source Header

    private var sourceHeader: some View {
        HStack(spacing: 14) {
            AccentIconBackground(systemName: "globe", size: 52, iconSize: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                if let desc = source.description, !desc.isEmpty {
                    Text(desc)
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    StatusBadge(text: "\(source.apps.count) apps", color: AppColors.accent)
                    if let fetched = source.lastFetched {
                        Text("Updated \(fetched.formatted(.relative(presentation: .named)))")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.disabledText)
                    }
                }
            }

            Spacer()
        }
        .appCard()
        .padding(.horizontal, 16)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                CategoryChip(
                    label: "All",
                    isSelected: selectedCat == nil,
                    onTap: { selectedCat = nil }
                )
                ForEach(categories, id: \.self) { cat in
                    CategoryChip(
                        label: cat,
                        isSelected: selectedCat == cat,
                        onTap: { selectedCat = selectedCat == cat ? nil : cat }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - App List

    @ViewBuilder
    private var appList: some View {
        if filteredApps.isEmpty {
            EmptyStateView(
                icon: "tray",
                title: searchText.isEmpty ? "No Apps" : "No Results",
                message: searchText.isEmpty
                    ? "This source doesn't list any apps yet."
                    : "No apps match \"\(searchText)\"."
            )
            .frame(minHeight: 200)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(filteredApps) { app in
                    SourceAppRow(app: app, source: source)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        isRefreshing = true
        let result = await SourceFetcher.shared.fetchSource(urlString: source.url)
        isRefreshing = false

        if let updated = result.source {
            source = updated
            dataManager.updateSource(byURL: source.url, with: updated)
        } else {
            refreshError = result.error ?? "Unknown error."
            showError = true
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(AppFont.small)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.accent : AppColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : AppColors.cardBorder, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - SourceAppRow

struct SourceAppRow: View {
    let app: SourceApp
    let source: Source

    @State private var iconImage: UIImage?    = nil
    @State private var downloadState: DownloadState = .idle

    enum DownloadState: Equatable {
        case idle
        case downloading
        case done
        case failed(String)
    }

    var isAlreadyImported: Bool {
        AppDataManager.shared.importedApps.contains { $0.bundleID == app.bundleID }
    }

    var body: some View {
        HStack(spacing: 14) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface2)
                    .frame(width: 56, height: 56)
                if let img = iconImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.disabledText)
                }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                Text(app.developerName)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("v\(app.version)")
                        .font(AppFont.small)
                        .foregroundColor(AppColors.disabledText)
                    if let size = app.size {
                        Text("·")
                            .foregroundColor(AppColors.disabledText)
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(AppFont.small)
                            .foregroundColor(AppColors.disabledText)
                    }
                    if let minOS = app.minOSVersion {
                        Text("·")
                            .foregroundColor(AppColors.disabledText)
                        Text("iOS \(minOS)+")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.disabledText)
                    }
                }
            }

            Spacer()

            // Download button
            downloadButton
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
        .task(id: app.iconURL) {
            await loadIcon()
        }
    }

    // MARK: - Download Button

    @ViewBuilder
    private var downloadButton: some View {
        switch downloadState {
        case .idle:
            Button {
                Task { await download() }
            } label: {
                if isAlreadyImported {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.success)
                } else {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isAlreadyImported)

        case .downloading:
            ZStack {
                Circle()
                    .stroke(AppColors.surface2, lineWidth: 3)
                    .frame(width: 36, height: 36)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(AppColors.accent)
                    .scaleEffect(0.7)
            }

        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(AppColors.success)
                .transition(.scale.combined(with: .opacity))

        case .failed:
            Button {
                downloadState = .idle
            } label: {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.destructive)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Download

    private func download() async {
        guard !app.downloadURL.isEmpty,
              let downloadURL = URL(string: app.downloadURL)
        else {
            downloadState = .failed("Invalid download URL.")
            return
        }

        withAnimation { downloadState = .downloading }

        do {
            // ── 1. Download IPA to temp ──────────────────────────────────
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)

            // ── 2. Move to Documents/IPAs/ ────────────────────────────────
            let ipaURL = try StorageManager.shared.storeIPA(from: tempURL)

            // ── 3. Analyze ────────────────────────────────────────────────
            let meta = try IPAAnalyzer.shared.analyze(ipaPath: ipaURL.path)

            // ── 4. Cache icon ─────────────────────────────────────────────
            let appID = UUID()
            if let iconData = meta.iconData {
                StorageManager.shared.storeIcon(iconData, appID: appID)
            }
            let iconPath = meta.iconData != nil
                ? StorageManager.shared.iconsURL
                    .appendingPathComponent("\(appID.uuidString).png").path
                : nil

            // ── 5. Build AppInfo ──────────────────────────────────────────
            let imported = AppInfo(
                id:                 appID,
                name:               meta.name,
                bundleID:           meta.bundleID,
                version:            meta.version,
                buildNumber:        meta.buildNumber,
                minOSVersion:       meta.minOSVersion,
                ipaPath:            ipaURL.path,
                iconPath:           iconPath,
                fileSize:           meta.fileSize,
                architectures:      meta.architectures,
                embeddedFrameworks: meta.embeddedFrameworks,
                isEncrypted:        meta.isEncrypted,
                isSigned:           meta.isSigned,
                isFavorite:         false,
                tags:               [],
                dateImported:       Date(),
                sourceURL:          app.downloadURL
            )

            await MainActor.run {
                AppDataManager.shared.addImportedApp(imported)
                withAnimation { downloadState = .done }
            }

        } catch {
            await MainActor.run {
                withAnimation { downloadState = .failed(error.localizedDescription) }
            }
        }
    }

    // MARK: - Icon Loading

    private func loadIcon() async {
        guard let urlStr = app.iconURL, let url = URL(string: urlStr) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data)
        else { return }
        await MainActor.run { iconImage = img }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SourceBrowserView(source: Source(
            id: UUID(), name: "Example Source",
            url: "https://example.com/apps.json",
            iconURL: nil,
            description: "A sample repository for preview purposes.",
            dateAdded: Date(), lastFetched: Date(),
            apps: []
        ))
    }
}
