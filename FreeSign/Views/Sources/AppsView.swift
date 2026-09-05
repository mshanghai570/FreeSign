import SwiftUI

// MARK: - AppsView

/// Aggregated view of every app available across all imported repositories.
/// Replaces the inline "Apps" section that used to sit below every repository
/// card in SourcesView, so apps are reachable with a single tap on the tab bar.
struct AppsView: View {
    @StateObject private var dataManager = AppDataManager.shared
    @State private var searchText    = ""
    @State private var isRefreshing  = false
    @State private var refreshError: String?
    @State private var showError     = false

    // MARK: - Aggregated Apps

    /// Every app from every source, deduplicated by bundle ID (first source wins).
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
        ZStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredSourceApps.isEmpty {
                        EmptyStateView(
                            icon: "app.dashed",
                            title: searchText.isEmpty ? "No Apps Yet" : "No Results",
                            message: searchText.isEmpty
                                ? "Add repositories in the Sources tab, then pull\nto refresh to load their apps here."
                                : "No apps match \"\(searchText)\"."
                        )
                        .frame(minHeight: 320)
                    } else {
                        ForEach(filteredSourceApps, id: \.app.id) { entry in
                            SourceAppRow(app: entry.app, source: entry.source)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .refreshable { await refreshAllSources() }

            if isRefreshing {
                LoadingOverlay(message: "Refreshing sources…")
            }
        }
        .appNavigationTitle("Apps")
        .appNavigationStyle()
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search apps…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refreshAllSources() }
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
            ToolbarItem(placement: .primaryAction) {
                TabAssistantButton(sourceView: "Apps", summary: appsAssistantSummary)
            }
        }
        .alert("Refresh Failed", isPresented: $showError, presenting: refreshError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in Text(msg) }
    }

    // MARK: - Assistant

    /// Summary of what is currently on the Apps tab, for the Lab Assistant.
    private var appsAssistantSummary: String {
        let total = allSourceApps.count
        let visible = filteredSourceApps.count
        let sources = dataManager.sources.count
        return "Apps tab: \(total) unique app(s) across \(sources) source(s)"
             + (searchText.isEmpty ? "" : " (\(visible) match \"\(searchText)\")") + "."
    }

    // MARK: - Refresh

    private func refreshAllSources() async {
        let urls = dataManager.sources.map { $0.url }
        guard !urls.isEmpty else { return }

        isRefreshing = true
        let results = await SourceFetcher.shared.fetchSources(urlStrings: urls)
        isRefreshing = false

        var failures: [String] = []
        for result in results {
            if let updated = result.source {
                dataManager.updateSource(byURL: result.url, with: updated)
            } else if let error = result.error {
                failures.append(error)
            }
        }
        if !failures.isEmpty {
            refreshError = failures.joined(separator: "\n")
            showError = true
        }
    }
}

#Preview {
    NavigationStack { AppsView() }
}
