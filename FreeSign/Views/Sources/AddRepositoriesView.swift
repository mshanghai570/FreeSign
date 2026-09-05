import SwiftUI

// MARK: - Add Repositories View

/// Lets users paste any number of repository URLs at once, fetches them concurrently,
/// and shows per-URL results before confirming which ones to add.
struct AddRepositoriesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = AddRepositoriesVM()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                switch vm.phase {
                case .input:   InputPhaseView(vm: vm, onDismiss: { dismiss() })
                case .fetching: FetchingPhaseView(vm: vm)
                case .results:  ResultsPhaseView(vm: vm, onDismiss: { dismiss() })
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - View Model

@MainActor
final class AddRepositoriesVM: ObservableObject {

    enum Phase { case input, fetching, results }

    @Published var phase: Phase = .input

    // Input phase
    @Published var pasteText: String = ""
    @Published var urlStates: [URLFetchState] = []

    // Computed from pasteText
    var detectedURLs: [String] {
        SourceFetcher.extractURLs(from: pasteText)
            .filter { url in !AppDataManager.shared.sources.contains { $0.url == url } }
            .removingDuplicates()
    }

    var alreadyAddedCount: Int {
        SourceFetcher.extractURLs(from: pasteText)
            .filter { url in AppDataManager.shared.sources.contains { $0.url == url } }
            .count
    }

    // Results phase
    var successResults: [URLFetchState] { urlStates.filter { $0.succeeded } }
    var failedResults:  [URLFetchState] { urlStates.filter { !$0.succeeded && !$0.isPending } }

    // MARK: - Actions

    func removeURL(_ url: String) {
        // Remove from pasteText by stripping the line containing this URL
        let lines = pasteText.components(separatedBy: .newlines)
        pasteText = lines.filter { !$0.contains(url) }.joined(separator: "\n")
    }

    func startFetch() {
        guard !detectedURLs.isEmpty else { return }
        urlStates = detectedURLs.map { URLFetchState(url: $0) }
        phase = .fetching

        Task {
            await withTaskGroup(of: Void.self) { group in
                for (i, url) in detectedURLs.enumerated() {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.fetchOne(index: i, url: url)
                    }
                }
            }
            // Move to results once all done
            phase = .results
        }
    }

    private func fetchOne(index: Int, url: String) async {
        await MainActor.run { urlStates[index].isLoading = true }
        let result = await SourceFetcher.shared.fetchSource(urlString: url)
        await MainActor.run {
            urlStates[index].isLoading = false
            urlStates[index].fetchResult = result
        }
    }

    func retryFailed() {
        let failed = failedResults.map { $0.url }
        pasteText = failed.joined(separator: "\n")
        urlStates = []
        phase = .input
    }

    func addSuccessful(then dismiss: () -> Void) {
        for state in successResults {
            if let source = state.fetchResult?.source {
                AppDataManager.shared.addSource(source)
            }
        }
        dismiss()
    }
}

// MARK: - URL Fetch State

struct URLFetchState: Identifiable {
    var id: String { url }
    let url: String
    var isLoading: Bool = false
    var fetchResult: SourceFetchResult? = nil

    var isPending:  Bool { !isLoading && fetchResult == nil }
    var succeeded:  Bool { fetchResult?.succeeded == true }
    var errorText:  String? { fetchResult?.error }

    var displayHost: String {
        URL(string: url)?.host ?? url
    }
}

// MARK: - Input Phase

private struct InputPhaseView: View {
    @ObservedObject var vm: AddRepositoriesVM
    let onDismiss: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ── Navigation bar ─────────────────────────────────────────────
            HStack {
                Spacer()
                Text("Add Repositories")
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button("Cancel") { onDismiss() }
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.trailing, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // ── Paste area ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                                .foregroundColor(AppColors.accent)
                            Text("Repository URLs")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding(.horizontal, 4)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $vm.pasteText)
                                .font(AppFont.mono)
                                .foregroundColor(AppColors.primaryText)
                                .scrollContentBackground(.hidden)
                                .focused($isFocused)
                                .frame(minHeight: 130)
                                .padding(14)
                                .background(AppColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            isFocused ? AppColors.accent : AppColors.cardBorder,
                                            lineWidth: 1
                                        )
                                )

                            if vm.pasteText.isEmpty {
                                Text("Paste one URL per line, or space/comma-separated.\ne.g.\nhttps://ipa.store/apps.json\nhttps://altstore.io/apps.json")
                                    .font(AppFont.mono)
                                    .foregroundColor(AppColors.disabledText)
                                    .padding(14 + 5)  // match TextEditor padding + inset
                                    .allowsHitTesting(false)
                            }
                        }

                        // Status line
                        HStack(spacing: 8) {
                            if vm.detectedURLs.isEmpty && vm.pasteText.isEmpty {
                                Text("Paste URLs above to get started")
                                    .font(AppFont.small)
                                    .foregroundColor(AppColors.disabledText)
                            } else {
                                if vm.detectedURLs.isEmpty && !vm.pasteText.isEmpty {
                                    Label("No valid URLs detected", systemImage: "exclamationmark.circle")
                                        .font(AppFont.small)
                                        .foregroundColor(AppColors.warning)
                                } else {
                                    Label("\(vm.detectedURLs.count) new URL\(vm.detectedURLs.count == 1 ? "" : "s") detected",
                                          systemImage: "checkmark.circle.fill")
                                        .font(AppFont.small)
                                        .foregroundColor(AppColors.success)
                                }
                                if vm.alreadyAddedCount > 0 {
                                    Text("·")
                                        .foregroundColor(AppColors.disabledText)
                                    Text("\(vm.alreadyAddedCount) already added")
                                        .font(AppFont.small)
                                        .foregroundColor(AppColors.disabledText)
                                }
                            }
                            Spacer()
                            if !vm.pasteText.isEmpty {
                                Button("Clear") { vm.pasteText = "" }
                                    .font(AppFont.small)
                                    .foregroundColor(AppColors.destructive)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 16)

                    // ── URL chips ──────────────────────────────────────────
                    if !vm.detectedURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Will be fetched:")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vm.detectedURLs, id: \.self) { url in
                                        URLChip(url: url) { vm.removeURL(url) }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeOut(duration: 0.2), value: vm.detectedURLs.count)
                    }

                    // ── Quick-add known repos ──────────────────────────────
                    KnownReposSection { url in
                        if vm.pasteText.isEmpty {
                            vm.pasteText = url
                        } else {
                            vm.pasteText += "\n" + url
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // ── Bottom action bar ──────────────────────────────────────────
            VStack(spacing: 10) {
                Button {
                    isFocused = false
                    vm.startFetch()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(vm.detectedURLs.isEmpty
                             ? "No URLs to Fetch"
                             : "Fetch \(vm.detectedURLs.count) Source\(vm.detectedURLs.count == 1 ? "" : "s")")
                    }
                }
                .appPrimaryButton()
                .disabled(vm.detectedURLs.isEmpty)
                .opacity(vm.detectedURLs.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
            .background(
                AppColors.background
                    .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isFocused = false
                }
                .font(AppFont.body.bold())
                .foregroundColor(AppColors.accent)
            }
        }
    }
}

// MARK: - Fetching Phase

private struct FetchingPhaseView: View {
    @ObservedObject var vm: AddRepositoriesVM

    var doneCount:  Int { vm.urlStates.filter { $0.fetchResult != nil }.count }
    var totalCount: Int { vm.urlStates.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                ProgressView(value: Double(doneCount), total: Double(max(totalCount, 1)))
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(AppColors.accent)
                    .frame(height: 4)
                    .padding(.horizontal, 20)

                Text("Fetching \(doneCount) / \(totalCount)…")
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)

                Text("Querying repositories in parallel")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Per-URL rows
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.urlStates) { state in
                        FetchProgressRow(state: state)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .animation(.easeOut(duration: 0.3), value: doneCount)
    }
}

// MARK: - Results Phase

private struct ResultsPhaseView: View {
    @ObservedObject var vm: AddRepositoriesVM
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 6) {
                Image(systemName: summaryIcon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(AppColors.accent, AppColors.disabledText.opacity(0.4))
                    .padding(.bottom, 4)

                Text(summaryTitle)
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)

                Text(summarySubtitle)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Results list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.urlStates) { state in
                        ResultRow(state: state)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }

            // Actions
            VStack(spacing: 10) {
                if !vm.successResults.isEmpty {
                    Button {
                        vm.addSuccessful(then: onDismiss)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add \(vm.successResults.count) Source\(vm.successResults.count == 1 ? "" : "s")")
                        }
                    }
                    .appPrimaryButton()
                    .padding(.horizontal, 16)
                }

                if !vm.failedResults.isEmpty {
                    Button { vm.retryFailed() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry \(vm.failedResults.count) Failed")
                        }
                    }
                    .appSecondaryButton()
                    .padding(.horizontal, 16)
                }

                Button("Done") { onDismiss() }
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.bottom, 4)
            }
            .padding(.vertical, 16)
            .background(
                AppColors.background
                    .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private var summaryIcon: String {
        if vm.failedResults.isEmpty { return "checkmark.seal.fill" }
        if vm.successResults.isEmpty { return "xmark.seal.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var summaryTitle: String {
        if vm.failedResults.isEmpty   { return "All Done" }
        if vm.successResults.isEmpty  { return "All Failed" }
        return "Partially Done"
    }

    private var summarySubtitle: String {
        let s = vm.successResults.count
        let f = vm.failedResults.count
        var parts: [String] = []
        if s > 0 { parts.append("\(s) succeeded") }
        if f > 0 { parts.append("\(f) failed") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - URL Chip

private struct URLChip: View {
    let url: String
    let onRemove: () -> Void

    var host: String { URL(string: url)?.host ?? url }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 11))
                .foregroundColor(AppColors.accent)

            Text(host)
                .font(AppFont.small)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppColors.disabledText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColors.cardBorder, lineWidth: 1))
    }
}

// MARK: - Fetch Progress Row

private struct FetchProgressRow: View {
    let state: URLFetchState

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.displayHost)
                    .font(AppFont.subhead)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                Text(state.url)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.disabledText)
                    .lineLimit(1)
            }

            Spacer()

            if let result = state.fetchResult, result.succeeded,
               let source = result.source {
                Text("\(source.apps.count) apps")
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(statusBorderColor, lineWidth: 1))
        .animation(.easeOut(duration: 0.3), value: state.isLoading)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if state.isPending {
            Circle()
                .stroke(AppColors.disabledText, lineWidth: 2)
                .frame(width: 20, height: 20)
        } else if state.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(AppColors.accent)
                .scaleEffect(0.8)
        } else if state.succeeded {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
                .font(.system(size: 20))
                .transition(.scale.combined(with: .opacity))
        } else {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(AppColors.destructive)
                .font(.system(size: 20))
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var statusBorderColor: Color {
        if state.succeeded { return AppColors.success.opacity(0.3) }
        if state.fetchResult != nil && !state.succeeded { return AppColors.destructive.opacity(0.3) }
        return AppColors.cardBorder
    }
}

// MARK: - Result Row

private struct ResultRow: View {
    let state: URLFetchState

    var body: some View {
        HStack(spacing: 14) {
            if state.succeeded {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.success.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.success)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.destructive.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.destructive)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(state.fetchResult?.source?.name ?? state.displayHost)
                    .font(AppFont.subhead)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                if state.succeeded, let source = state.fetchResult?.source {
                    Text("\(source.apps.count) app\(source.apps.count == 1 ? "" : "s") · \(state.displayHost)")
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                } else if let err = state.errorText {
                    Text(err)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.destructive)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(state.succeeded
                        ? AppColors.success.opacity(0.25)
                        : AppColors.destructive.opacity(0.25),
                        lineWidth: 1)
        )
    }
}

// MARK: - Known Repos Section

private struct KnownReposSection: View {
    let onSelect: (String) -> Void

    // A curated starter list
    private let repos: [(name: String, url: String, description: String)] = [
        ("AltStore",    "https://apps.altstore.io",                               "Official AltStore source"),
        ("Havoc",       "https://havoc.app/api/cydia",                            "Popular paid apps"),
        ("PolyMars",    "https://repo.polymars.dev/altstore/apps.json",           "Indie games & utilities"),
        ("Quiprr",      "https://quiprr.dev/repo.json",                           "Tweaks & tools"),
        ("WhisperMint", "https://whispermint.com/apps.json",                      "Community source"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular Sources")
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 1) {
                ForEach(repos, id: \.url) { repo in
                    let isAdded = AppDataManager.shared.sources.contains { $0.url == repo.url }

                    Button {
                        if !isAdded { onSelect(repo.url) }
                    } label: {
                        HStack(spacing: 12) {
                            AccentIconBackground(systemName: "globe", size: 36, iconSize: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.name)
                                    .font(AppFont.subhead)
                                    .foregroundColor(isAdded ? AppColors.disabledText : AppColors.primaryText)
                                Text(repo.description)
                                    .font(AppFont.small)
                                    .foregroundColor(AppColors.disabledText)
                            }

                            Spacer()

                            if isAdded {
                                StatusBadge(text: "Added", color: AppColors.success)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAdded)

                    if repo.url != repos.last?.url {
                        AppDivider(leadingPadding: 64)
                    }
                }
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Array dedup helper


