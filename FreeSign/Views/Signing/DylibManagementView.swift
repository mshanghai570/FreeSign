import SwiftUI
import UniformTypeIdentifiers

// MARK: - Dylib Management View

/// View for managing dylibs to be injected into IPAs (ZSign feature)
struct DylibManagementView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var injectDylibs: [String]
    
    @StateObject private var dylibManager = DylibManager.shared
    @StateObject private var theme = ThemeManager.shared
    
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Current dylibs to inject
                currentDylibsSection
                
                // Available dylibs
                availableDylibsSection
                
                Spacer(minLength: 40)
            }
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background(theme.backgroundView)
        .appNavigationTitle("Manage Dylibs")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(theme.accentColor)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundColor(theme.accentColor)
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
            allowsMultipleSelection: true
        ) { result in
            handleFilePicker(result: result)
        }
        .alert("Import Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .overlay {
            if isImporting {
                LoadingOverlay(message: "Importing dylibs...")
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.stack")
                .font(.system(size: 28))
                .foregroundColor(theme.accentColor)
            
            Text("Dylib Management")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
            
            Text("Add dylibs to be injected into the IPA during signing.")
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
                Text("Dylibs to Inject (\(injectDylibs.count))")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if !injectDylibs.isEmpty {
                    Button {
                        injectDylibs.removeAll()
                    } label: {
                        Text("Clear All")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.destructive)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            if injectDylibs.isEmpty {
                EmptyStateView(
                    icon: "cube",
                    title: "No Dylibs to Inject",
                    message: "Add dylibs from the available list below or import new ones.",
                    actionTitle: nil,
                    action: nil
                )
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(0..<injectDylibs.count, id: \.self) { index in
                        DylibToInjectRow(
                            path: injectDylibs[index],
                            onRemove: {
                                injectDylibs.remove(at: index)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
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
            
            if dylibManager.availableDylibs.isEmpty {
                EmptyStateView(
                    icon: "tray.and.arrow.up",
                    title: "No Dylibs Available",
                    message: "Import .dylib files to make them available for injection.",
                    actionTitle: "Import Dylib",
                    action: { showFilePicker = true }
                )
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(dylibManager.availableDylibs) { dylib in
                        AvailableDylibRow(
                            dylib: dylib,
                            isSelected: injectDylibs.contains(dylib.path),
                            onToggle: {
                                if injectDylibs.contains(dylib.path) {
                                    injectDylibs.removeAll { $0 == dylib.path }
                                } else {
                                    injectDylibs.append(dylib.path)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func handleFilePicker(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            let code = (error as NSError).code
            if code != NSUserCancelledError && code != -1 {
                importError = "Could not open file picker: \(error.localizedDescription)"
                showError = true
            }
        
        case .success(let urls):
            importDylibs(from: urls)
        }
    }
    
    private func importDylibs(from urls: [URL]) {
        var errors: [String] = []
        var importedCount = 0
        
        for url in urls {
            do {
                let dylib = try dylibManager.importDylib(from: url)
                // Add to inject list if not already there
                if !injectDylibs.contains(dylib.path) {
                    injectDylibs.append(dylib.path)
                }
                importedCount += 1
            } catch {
                errors.append(url.lastPathComponent + ": " + error.localizedDescription)
            }
        }
        
        if !errors.isEmpty {
            importError = "Imported \(importedCount) of \(urls.count) files. Errors: \(errors.joined(separator: ", "))"
            showError = true
        }
    }
}

// MARK: - Dylib To Inject Row

struct DylibToInjectRow: View {
    let path: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "cube")
                .font(.system(size: 14))
                .foregroundColor(ThemeManager.shared.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                
                Text(path)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.destructive)
            }
        }
        .padding(.vertical, 8)
    }
}



// MARK: - Preview

#Preview {
    NavigationStack {
        DylibManagementView(injectDylibs: .constant([]))
    }
}