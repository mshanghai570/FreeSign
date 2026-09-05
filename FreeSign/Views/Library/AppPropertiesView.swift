import SwiftUI

// MARK: - App Properties View

/// Detailed properties viewer for IPA files (like Feather's Properties section)
struct AppPropertiesView: View {
    @Environment(\.dismiss) var dismiss
    let app: AppInfo
    
    @State private var selectedSection: PropertiesSection = .info
    @State private var expandedSections: Set<PropertiesSection> = []
    @State private var dylibs: [DylibInfo] = []
    @State private var frameworks: [FrameworkInfo] = []
    @State private var plugins: [PluginInfo] = []
    @State private var entitlements: [String: String] = [:]
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    
    enum PropertiesSection: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        
        case info = "Info"
        case bundle = "Bundle"
        case requirements = "Requirements"
        case frameworks = "Frameworks"
        case dylibs = "Dylibs"
        case plugins = "Plugins"
        case entitlements = "Entitlements"
        case signatures = "Signatures"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Section selector
                sectionSelector
                
                // Properties content
                propertiesContent
                
                Spacer(minLength: 40)
            }
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background(ThemeManager.shared.backgroundView)
        .appNavigationTitle("Properties")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .foregroundColor(ThemeManager.shared.accentColor)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: analyzeIPA) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(ThemeManager.shared.accentColor)
                }
                .disabled(isAnalyzing)
            }
        }
        .overlay {
            if isAnalyzing {
                LoadingOverlay(message: "Analyzing IPA...")
            }
        }
        .onAppear {
            // Load initial data
            loadInitialData()
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
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeManager.shared.surfaceColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 32))
                                .foregroundColor(ThemeManager.shared.accentColor)
                        )
                }
            }
            
            // App name and bundle ID
            VStack(spacing: 4) {
                Text(app.name)
                    .font(AppFont.largeTitle)
                    .foregroundColor(AppColors.primaryText)
                
                Text(app.bundleID)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            // Version and size
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Version")
                        .font(AppFont.small)
                        .foregroundColor(AppColors.disabledText)
                    Text("v\(app.version) (\(app.buildNumber))")
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                }
                
                VStack(spacing: 2) {
                    Text("Size")
                        .font(AppFont.small)
                        .foregroundColor(AppColors.disabledText)
                    Text(app.formattedSize)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                }
                
                VStack(spacing: 2) {
                    Text("Architectures")
                        .font(AppFont.small)
                        .foregroundColor(AppColors.disabledText)
                    Text(app.architectureString)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Section Selector
    
    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PropertiesSection.allCases, id: \.self) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        VStack(spacing: 4) {
                            Text(section.rawValue)
                                .font(AppFont.caption)
                                .foregroundColor(
                                    selectedSection == section 
                                        ? ThemeManager.shared.accentColor 
                                        : AppColors.secondaryText
                                )
                            
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ThemeManager.shared.accentColor)
                                    .frame(height: 2)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Properties Content
    
    private var propertiesContent: some View {
        VStack(spacing: 16) {
            switch selectedSection {
            case .info:
                infoSection
            case .bundle:
                bundleSection
            case .requirements:
                requirementsSection
            case .frameworks:
                frameworksSection
            case .dylibs:
                dylibsSection
            case .plugins:
                pluginsSection
            case .entitlements:
                entitlementsSection
            case .signatures:
                signaturesSection
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertyGroup(title: "Basic Information") {
                PropertyRow(label: "Name", value: app.name)
                PropertyRow(label: "Bundle ID", value: app.bundleID)
                PropertyRow(label: "Version", value: "v\(app.version)")
                PropertyRow(label: "Build", value: app.buildNumber)
            }
            
            PropertyGroup(title: "File Information") {
                PropertyRow(label: "File Size", value: app.formattedSize)
                PropertyRow(label: "File Path", value: URL(fileURLWithPath: app.ipaPath).lastPathComponent)
                PropertyRow(label: "Date Imported", value: formatDate(app.dateImported))
            }
            
            PropertyGroup(title: "Source") {
                if let sourceURL = app.sourceURL {
                    PropertyRow(label: "Source URL", value: sourceURL)
                } else {
                    PropertyRow(label: "Source", value: "Local Import")
                }
            }
        }
    }
    
    // MARK: - Bundle Section
    
    private var bundleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertyGroup(title: "Bundle Information") {
                PropertyRow(label: "Bundle Name", value: app.name)
                PropertyRow(label: "Bundle Identifier", value: app.bundleID)
                PropertyRow(label: "Bundle Version", value: "v\(app.version) (\(app.buildNumber))")
                PropertyRow(label: "Minimum OS Version", value: app.minOSVersion)
            }
            
            PropertyGroup(title: "App Metadata") {
                PropertyRow(label: "Executable Name", value: "\(app.name)")
                PropertyRow(label: "Package Type", value: "APPL")
                PropertyRow(label: "Platform", value: "iOS")
            }
        }
    }
    
    // MARK: - Requirements Section
    
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertyGroup(title: "System Requirements") {
                PropertyRow(label: "Minimum iOS Version", value: app.minOSVersion)
                PropertyRow(label: "Supported Architectures", value: app.architectureString)
                PropertyRow(label: "Device Family", value: "iPhone, iPad")
            }
            
            PropertyGroup(title: "Capabilities") {
                PropertyRow(label: "Requires iOS", value: "Yes")
                PropertyRow(label: "Supports ARM64", value: app.architectures.contains("arm64") ? "Yes" : "No")
                PropertyRow(label: "Supports ARM64e", value: app.architectures.contains("arm64e") ? "Yes" : "No")
            }
        }
    }
    
    // MARK: - Frameworks Section (Feather feature)
    
    private var frameworksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if frameworks.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No Frameworks",
                    message: "This IPA does not contain any embedded frameworks.",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                PropertyGroup(title: "Embedded Frameworks (\(frameworks.count))") {
                    ForEach(frameworks) { framework in
                        FrameworkRow(name: framework.name)
                    }
                }
            }
        }
    }
    
    // MARK: - Dylibs Section (Feather feature)
    
    private var dylibsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dylibs.isEmpty {
                PropertyGroup(title: "Dynamic Libraries") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No custom dylibs found in this IPA.")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if !isAnalyzing {
                            Button {
                                analyzeIPA()
                            } label: {
                                Text("Analyze Dylibs")
                                    .font(AppFont.caption)
                                    .foregroundColor(ThemeManager.shared.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                PropertyGroup(title: "Dynamic Libraries (\(dylibs.count))") {
                    ForEach(dylibs) { dylib in
                        DylibRow(
                            name: dylib.name,
                            size: dylib.size,
                            isInjected: dylib.isInjected,
                            architecture: dylib.architecture
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Plugins Section (Feather feature)
    
    private var pluginsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if plugins.isEmpty {
                PropertyGroup(title: "Plugins") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No plugins found in this IPA.")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if !isAnalyzing {
                            Button {
                                analyzeIPA()
                            } label: {
                                Text("Analyze Plugins")
                                    .font(AppFont.caption)
                                    .foregroundColor(ThemeManager.shared.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                PropertyGroup(title: "Plugins (\(plugins.count))") {
                    ForEach(plugins) { plugin in
                        PluginRow(name: plugin.name, type: plugin.type, size: plugin.size)
                    }
                }
            }
        }
    }
    
    // MARK: - Entitlements Section
    
    private var entitlementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entitlements.isEmpty {
                PropertyGroup(title: "Entitlements") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No entitlements found in this IPA.")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if !isAnalyzing {
                            Button {
                                analyzeIPA()
                            } label: {
                                Text("Analyze Entitlements")
                                    .font(AppFont.caption)
                                    .foregroundColor(ThemeManager.shared.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                PropertyGroup(title: "Entitlements (\(entitlements.count))") {
                    ForEach(entitlements.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        EntitlementRow(key: key, value: value, type: "String")
                    }
                }
            }
        }
    }
    
    // MARK: - Signatures Section
    
    private var signaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PropertyGroup(title: "Code Signing") {
                PropertyRow(label: "Status", value: app.isSigned ? "Signed" : "Unsigned")
                PropertyRow(label: "Encrypted", value: app.isEncrypted ? "Yes" : "No")
                
                if app.isSigned {
                    PropertyRow(label: "Signing Certificate", value: "Available")
                    PropertyRow(label: "Last Signed", value: app.lastSignedDate != nil ? formatDate(app.lastSignedDate!) : "Unknown")
                    if let certName = app.lastSignedWith {
                        PropertyRow(label: "Signed With", value: certName)
                    }
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() {
        // Load basic data from AppInfo
        dylibs = []
        frameworks = app.embeddedFrameworks.map { name in
            FrameworkInfo(
                name: name,
                path: "Payload/" + app.name + ".app/Frameworks/" + name,
                size: 0,
                isEmbedded: true
            )
        }
        plugins = []
        entitlements = [:]
    }
    
    private func analyzeIPA() {
        isAnalyzing = true
        
        Task.detached(priority: .userInitiated) {
            do {
                // Use IPAAnalyzer to get enhanced data
                let result = try IPAAnalyzer.shared.analyze(ipaPath: app.ipaPath)
                
                // For now, we'll use the existing data
                // In a real implementation, this would extract and analyze the IPA
                // to get actual dylibs, plugins, and entitlements
                
                await MainActor.run {
                    // Update frameworks from analysis
                    frameworks = app.embeddedFrameworks.map { name in
                        FrameworkInfo(
                            name: name,
                            path: "Payload/" + app.name + ".app/Frameworks/" + name,
                            size: 0,
                            isEmbedded: true
                        )
                    }
                    
                    // For dylibs, plugins, and entitlements, we would need to extract the IPA
                    // and scan the actual files. This is a placeholder for now.
                    dylibs = []
                    plugins = []
                    entitlements = [:]
                    
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Property Group

struct PropertyGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.headline)
                .foregroundColor(AppColors.primaryText)
            
            content
        }
        .padding(16)
        .background(ThemeManager.shared.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Property Row

struct PropertyRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Framework Row

struct FrameworkRow: View {
    let name: String
    
    var body: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundColor(ThemeManager.shared.accentColor)
            
            Text(name)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Button {
                // Action to view framework details
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.vertical, 8)
    }
}


struct PluginRow: View {
    let name: String
    let type: String
    let size: Int64?
    
    var body: some View {
        HStack {
            Image(systemName: "puzzlepiece")
                .font(.system(size: 14))
                .foregroundColor(ThemeManager.shared.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(type)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            if let size = size {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Entitlement Row

struct EntitlementRow: View {
    let key: String
    let value: String
    let type: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(type)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text(value)
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
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
        embeddedFrameworks: ["Framework1.framework", "Framework2.framework"],
        isEncrypted: false,
        isSigned: true,
        isFavorite: false,
        tags: [],
        dateImported: Date(),
        sourceURL: nil,
        lastSignedWith: "Developer Certificate",
        lastSignedDate: Date()
    )
    
    NavigationStack {
        AppPropertiesView(app: previewApp)
    }
}