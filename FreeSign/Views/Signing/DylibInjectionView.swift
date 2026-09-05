import SwiftUI
import UniformTypeIdentifiers

// MARK: - Dylib Injection View

/// View for injecting dylibs into IPAs (ZSign feature)
struct DylibInjectionView: View {
    @Environment(\.dismiss) var dismiss
    let app: AppInfo
    
    @StateObject private var dylibManager = DylibManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    
    @State private var showFilePicker = false
    @State private var isInjecting = false
    @State private var injectionProgress = ""
    @State private var injectionError: String?
    @State private var showError = false
    @State private var selectedDylib: DylibFile?
    @State private var injectionOptions = DylibInjectionOptions.default
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Current dylibs in IPA
                currentDylibsSection
                
                // Available dylibs
                availableDylibsSection
                
                // Injection options
                if selectedDylib != nil {
                    injectionOptionsSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundView)
        .appNavigationTitle("Dylib Injection")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(theme.accentColor)
            }
            
            if selectedDylib != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Inject") {
                        injectSelectedDylib()
                    }
                    .foregroundColor(theme.accentColor)
                    .disabled(isInjecting)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType("com.apple.mach-o.dynamic-shared-library"),
                UTType(filenameExtension: "dylib"),
                UTType(filenameExtension: "so"),
                .data
            ].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            handleFilePicker(result: result)
        }
        .alert("Injection Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(injectionError ?? "Unknown error")
        }
        .overlay {
            if isInjecting {
                LoadingOverlay(message: injectionProgress)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // App icon
            ZStack {
                if let iconPath = app.iconPath, let uiImage = UIImage(contentsOfFile: iconPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.surfaceColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 24))
                                .foregroundColor(theme.accentColor)
                        )
                }
            }
            
            // App info
            VStack(spacing: 4) {
                Text(app.name)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(app.bundleID)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // Description
            Text("Inject custom dylibs into this IPA for advanced functionality.")
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Current Dylibs Section
    
    private var currentDylibsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Dylibs")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button {
                    // Refresh dylib analysis
                    analyzeCurrentDylibs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accentColor)
                }
            }
            .padding(.horizontal, 4)
            
            // Current dylibs list
            VStack(spacing: 8) {
                if dylibManager.analyzeDylibs(in: app.ipaPath).isEmpty {
                    EmptyStateView(
                        icon: "cube",
                        title: "No Dylibs Found",
                        message: "This IPA does not contain any custom dylibs.",
                        actionTitle: nil,
                        action: nil
                    )
                    .padding(.vertical, 20)
                } else {
                    ForEach(dylibManager.analyzeDylibs(in: app.ipaPath)) { dylib in
                        DetailedDylibRow(
                            name: dylib.name,
                            size: dylib.size,
                            isInjected: dylib.isInjected,
                            architecture: dylib.architecture
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Available Dylibs Section
    
    private var availableDylibsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Dylibs")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Import")
                    }
                    .font(AppFont.caption)
                    .foregroundColor(theme.accentColor)
                }
            }
            .padding(.horizontal, 4)
            
            availableDylibsList
        }
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
    
    private var availableDylibsList: some View {
        VStack(spacing: 8) {
            if dylibManager.availableDylibs.isEmpty {
                EmptyStateView(
                    icon: "tray.and.arrow.up",
                    title: "No Dylibs Available",
                    message: "Import a .dylib file to inject into IPAs.",
                    actionTitle: "Import Dylib",
                    action: { showFilePicker = true }
                )
                .padding(.vertical, 20)
            } else {
                ForEach(dylibManager.availableDylibs) { dylib in
                    Button {
                        selectedDylib = dylib
                    } label: {
                        AvailableDylibRow(
                            dylib: dylib,
                            isSelected: selectedDylib?.id == dylib.id
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Injection Options Section
    
    private var injectionOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Injection Options")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                // Overwrite existing
                ToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Overwrite Existing",
                    subtitle: "Replace existing dylibs with same name",
                    isOn: Binding(
                        get: { injectionOptions.overwriteExisting },
                        set: { injectionOptions.overwriteExisting = $0 }
                    )
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Backup original
                ToggleRow(
                    icon: "doc.on.doc",
                    title: "Backup Original",
                    subtitle: "Create backup before injecting",
                    isOn: Binding(
                        get: { injectionOptions.backupOriginal },
                        set: { injectionOptions.backupOriginal = $0 }
                    )
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Verify signature
                ToggleRow(
                    icon: "checkmark.shield",
                    title: "Verify Signature",
                    subtitle: "Verify IPA signature after injection",
                    isOn: Binding(
                        get: { injectionOptions.verifySignature },
                        set: { injectionOptions.verifySignature = $0 }
                    )
                )
            }
            .background(theme.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                injectionError = "Could not open file picker: \(error.localizedDescription)"
                showError = true
            }
        
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let dylib = try dylibManager.importDylib(from: url)
                selectedDylib = dylib
            } catch {
                injectionError = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func injectSelectedDylib() {
        guard let dylib = selectedDylib else { return }
        
        isInjecting = true
        injectionProgress = "Injecting dylib…"
        
        Task.detached(priority: .userInitiated) {
            do {
                let outputPath = try await DylibManager.shared.injectDylib(
                    dylib.path,
                    into: app.ipaPath,
                    options: injectionOptions
                )
                
                await MainActor.run {
                    isInjecting = false
                    injectionProgress = ""
                    
                    // Show success message
                    // In a real implementation, you might want to navigate to the output IPA
                    print("Dylib injected successfully: \(outputPath)")
                    
                    // Reset selection
                    selectedDylib = nil
                }
            } catch {
                await MainActor.run {
                    isInjecting = false
                    injectionError = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func analyzeCurrentDylibs() {
        // Refresh the dylib analysis
        // In a real implementation, this would re-extract and analyze the IPA
        print("Analyzing dylibs in: \(app.name)")
    }
}







// MARK: - Preview

#Preview {
    let previewApp = AppInfo(
        id: UUID(),
        name: "Test App",
        bundleID: "com.example.test",
        version: "1.0.0",
        buildNumber: "1",
        minOSVersion: "15.0",
        ipaPath: "/path/to/test.ipa",
        iconPath: nil,
        fileSize: 1024 * 1024,
        architectures: ["arm64"],
        embeddedFrameworks: ["Framework1.framework"],
        isEncrypted: false,
        isSigned: true,
        isFavorite: false,
        tags: [],
        dateImported: Date(),
        sourceURL: nil
    )
    
    NavigationStack {
        DylibInjectionView(app: previewApp)
    }
}
