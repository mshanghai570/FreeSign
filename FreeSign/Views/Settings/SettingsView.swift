import SwiftUI

struct SettingsView: View {
    @StateObject private var dataManager = AppDataManager.shared
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var settings = Settings.shared
    @State private var showCleanupAlert = false
    @State private var showResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Statistics
                statsSection
                
                // Theme Settings
                themeSettingsSection
                
                // Appearance Settings
                appearanceSettingsSection
                
                // App Settings
                appSettingsSection
                
                // Device Info
                deviceInfoSection
                
                // Advanced Settings
                advancedSettingsSection
                
                // Certificates
                certificatesSection
                
                // Quick Links
                quickLinksSection
                
                // About
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(ThemeManager.shared.backgroundView)
        .scrollDismissesKeyboard(.interactively)
        .appNavigationTitle("Settings")
        .appNavigationStyle()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .font(AppFont.body.bold())
                .foregroundColor(theme.accentColor)
            }
            ToolbarItem(placement: .primaryAction) {
                TabAssistantButton(
                    sourceView: "Settings",
                    summary: settingsAssistantSummary,
                    details: settingsAssistantDetails
                )
            }
        }
        .alert("Clean Temporary Files?", isPresented: $showCleanupAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                cleanupTemporaryFiles()
            }
        } message: {
            Text("This will remove all temporary extraction files. This action cannot be undone.")
        }
        .alert("Reset All Settings?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset and Erase AI Data", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This restores FreeSign preferences and permanently removes AI provider configurations, API keys, and saved assistant conversations. Imported IPAs and certificates are not deleted.")
        }
    }
    
    // MARK: - Assistant
    
    private var settingsAssistantSummary: String {
        let certs = dataManager.certificates.count
        let imported = dataManager.importedApps.count
        let installed = dataManager.installedApps.count
        return "Settings tab: \(certs) certificate(s), \(imported) imported app(s), "
             + "\(installed) signed app(s). Theme: \(theme.preset.displayName)."
    }

    private var settingsAssistantDetails: [String: Any] {
        [
            "theme": theme.preset.displayName,
            "cardStyle": theme.cardStyle.displayName,
            "backgroundPhotoEnabled": theme.hasPhoto,
            "appIconStyle": theme.appIconStyle.displayName,
            "showAppIcons": theme.showAppIcons,
            "smoothAnimations": settings.showAnimations,
            "autoImportFromRepos": settings.autoImportFromRepos,
            "confirmDeletions": settings.confirmDeletions,
            "showTips": settings.showTips,
            "developerMode": settings.developerMode,
            "assistantProviderActive": AISettings.shared.hasActiveProvider
        ]
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "gearshape")
                .font(.system(size: 36))
                .foregroundColor(theme.accentColor)
            
            Text("FreeSign")
                .font(AppFont.largeTitle)
                .foregroundColor(AppColors.primaryText)
            
            Text("Professional IPA Signing Workstation")
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Statistics
    
    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                icon: "checkmark.shield",
                value: "\(dataManager.certificates.count)",
                label: "Certificates",
                color: theme.accentColor
            )
            StatCard(
                icon: "tray.and.arrow.down",
                value: "\(dataManager.importedApps.count)",
                label: "Imported",
                color: AppColors.secondaryText
            )
            StatCard(
                icon: "square.on.square",
                value: "\(dataManager.installedApps.count)",
                label: "Signed",
                color: theme.accentColor
            )
        }
    }
    
    // MARK: - Theme Settings
    
    private var themeSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Theme")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                NavigationLink(destination: ThemeView()) {
                    Text("See All")
                        .font(AppFont.caption)
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 4)
            
            // Theme preview and quick access
            VStack(spacing: 1) {
                // Current theme preview
                HStack(spacing: 12) {
                    // Theme icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.surfaceColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                        
                        if theme.hasPhoto {
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundColor(theme.accentColor)
                        } else {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 18))
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    
                    // Theme info
                    VStack(alignment: .leading, spacing: 1) {
                        Text(theme.preset.displayName)
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                        
                        if theme.hasPhoto {
                            Text("Photo Background")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                        } else {
                            Text("Color Theme")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    // Theme actions
                    HStack(spacing: 8) {
                        Button {
                            // Toggle photo background
                            theme.hasPhoto.toggle()
                            if !theme.hasPhoto {
                                theme.removePhoto()
                            }
                        } label: {
                            Image(systemName: theme.hasPhoto ? "photo" : "paintpalette")
                                .font(.system(size: 14))
                                .foregroundColor(theme.accentColor)
                                .padding(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        
                        NavigationLink(destination: ThemeView()) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.disabledText)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Quick theme presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ThemePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                            Button {
                                theme.preset = preset
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: preset.accentHex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: preset.accentHex).opacity(0.3), lineWidth: 2)
                                        )
                                    
                                    Text(preset.displayName)
                                        .font(AppFont.small)
                                        .foregroundColor(AppColors.secondaryText)
                                        .frame(width: 60)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                                .background(theme.preset == preset ? theme.accentColor.opacity(0.1) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.preset == preset ? theme.accentColor : .clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                // Card Style
                ToggleRow(
                    icon: "rectangle.stack",
                    title: "Glass Card Style",
                    subtitle: theme.cardStyle == .glass ? "Enabled" : "Disabled",
                    isOn: Binding(
                        get: { theme.cardStyle == .glass },
                        set: { isGlass in
                            theme.cardStyle = isGlass ? .glass : .outlined
                        }
                    )
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Animations
                ToggleRow(
                    icon: "sparkles",
                    title: "Smooth Animations",
                    subtitle: "Enable fluid transitions",
                    isOn: Binding(
                        get: { settings.showAnimations },
                        set: {
                            settings.showAnimations = $0
                            settings.save()
                        }
                    )
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // App Icon Style (Feather feature)
                PickerRow(
                    icon: "app.fill",
                    title: "App Icon Style",
                    selection: Binding(
                        get: { theme.appIconStyle },
                        set: { theme.appIconStyle = $0 }
                    ),
                    options: [
                        PickerOption(title: "System", value: AppIconStyle.system),
                        PickerOption(title: "Rounded", value: AppIconStyle.rounded),
                        PickerOption(title: "Squared", value: AppIconStyle.squared)
                    ]
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Show App Icons
                ToggleRow(
                    icon: "app.fill",
                    title: "Show App Icons",
                    subtitle: "Display app icons in lists",
                    isOn: Binding(
                        get: { theme.showAppIcons },
                        set: { theme.showAppIcons = $0 }
                    )
                )
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - App Settings
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Settings")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                // Auto Import
                ToggleRow(
                    icon: "tray.and.arrow.down",
                    title: "Auto Import from Repos",
                    subtitle: "Automatically import apps from repositories",
                    isOn: Binding(
                        get: { settings.autoImportFromRepos },
                        set: {
                            settings.autoImportFromRepos = $0
                            settings.save()
                        }
                    )
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Confirm Deletions
                ToggleRow(
                    icon: "trash",
                    title: "Confirm Deletions",
                    subtitle: "Ask before deleting apps or certificates",
                    isOn: Binding(
                        get: { settings.confirmDeletions },
                        set: {
                            settings.confirmDeletions = $0
                            settings.save()
                        }
                    )
                )
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Show Tips
                ToggleRow(
                    icon: "lightbulb",
                    title: "Show Tips",
                    subtitle: "Display helpful tips and hints",
                    isOn: Binding(
                        get: { settings.showTips },
                        set: {
                            settings.showTips = $0
                            settings.save()
                        }
                    )
                )
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Device Info
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device Info")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                AboutRow(title: "Device Name", value: UIDevice.current.name)
                AboutRow(title: "System Version", value: UIDevice.current.systemVersion)
                AboutRow(title: "Model", value: UIDevice.current.model)
                AboutRow(title: "Identifier", value: UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Advanced")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                // Developer mode toggle
                Button {
                    settings.developerMode.toggle()
                    settings.save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: settings.developerMode ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundColor(settings.developerMode ? AppColors.success : AppColors.disabledText)
                        
                        Text("Developer Mode")
                            .font(AppFont.caption)
                            .foregroundColor(settings.developerMode ? AppColors.success : AppColors.disabledText)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 4)
            
            if settings.developerMode {
                VStack(spacing: 1) {
                    // Debug options
                    Button(action: {
                        exportDebugInfo()
                    }) {
                        SettingsRow(
                            icon: "doc.text",
                            title: "Export Debug Info",
                            subtitle: "Save app state for debugging",
                            color: AppColors.info
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())

                    Divider()
                        .background(AppColors.cardBorder)
                        .padding(.leading, 16)

                    Button(action: {
                        showResetAlert = true
                    }) {
                        SettingsRow(
                            icon: "arrow.clockwise",
                            title: "Reset All Settings",
                            subtitle: "Restore default preferences",
                            color: AppColors.destructive
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
                .background(ThemeManager.shared.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Certificates
    
    private var certificatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certificates")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                NavigationLink(destination: CertificatesView(embeddedInSettings: true)) {
                    SettingsRow(
                        icon: "checkmark.shield",
                        title: "Manage Certificates",
                        subtitle: "\(dataManager.certificates.count) certificate(s) imported",
                        color: theme.accentColor
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .accessibilityIdentifier("settings.manageCertificates")

                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)

                Button(action: { installUUIDProfile() }) {
                    SettingsRow(
                        icon: "cpu",
                        title: "Install UUID Profile",
                        subtitle: "Extract device UUID for signing",
                        color: AppColors.info
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Quick Links
    
    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Links")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                NavigationLink(destination: SourcesView()) {
                    SettingsRow(
                        icon: "tray.and.arrow.down",
                        title: "Manage Sources",
                        subtitle: "Configure IPA repositories",
                        color: theme.accentColor
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())

                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)

                NavigationLink(destination: AppsView()) {
                    SettingsRow(
                        icon: "square.grid.2x2",
                        title: "Browse All Apps",
                        subtitle: "\(allSourceAppCount) app(s) across all repositories",
                        color: theme.accentColor
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())

                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)

                NavigationLink(destination: AssistantSettingsView()) {
                    SettingsRow(
                        icon: "brain",
                        title: "Lab Assistant",
                        subtitle: "AI providers and settings",
                        color: AppColors.info
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .accessibilityIdentifier("settings.labAssistant")

                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)

                NavigationLink(destination: LibraryView()) {
                    SettingsRow(
                        icon: "square.on.square",
                        title: "Imported Apps",
                        subtitle: "\(dataManager.importedApps.count) app(s)",
                        color: AppColors.secondaryText
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)
            
            VStack(spacing: 1) {
                AboutRow(title: "Version", value: appVersion)
                AboutRow(title: "Build", value: buildNumber)
                AboutRow(title: "Zsign Engine", value: "v1.2")
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                Text("Inspired by:")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.disabledText)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                
                LinkRow(title: "Feather (UI Reference)", url: "https://github.com/claration/Feather")
                LinkRow(title: "Zsign (Signing Engine)", url: "https://github.com/zhlynn/zsign")
                LinkRow(title: "eSign+ (Feature Reference)", url: "https://github.com/eSignPlus/eSignPlus")
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                Text("Created by Michael Shingara")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.disabledText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private var allSourceAppCount: Int {
        var seen = Set<String>()
        var count = 0
        for source in dataManager.sources {
            for app in source.apps {
                let key = app.bundleID.isEmpty ? app.id.uuidString : app.bundleID
                if seen.insert(key).inserted {
                    count += 1
                }
            }
        }
        return count
    }
    
    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func cleanupTemporaryFiles() {
        StorageManager.shared.cleanupAllExtracts()
        print("Temporary files cleaned up")
    }
    
    private func exportDebugInfo() {
        print("Exporting debug info...")
        // This would save to a file and show share sheet
    }
    
    private func resetAllSettings() {
        // Reset theme settings
        theme.preset = .bronzeVault
        theme.cardStyle = .outlined
        theme.hasPhoto = false
        theme.removePhoto()
        theme.appIconStyle = .system
        theme.signingBehavior = .ask
        theme.certificateValidation = .strict
        theme.repositoryBehavior = .manualRefresh
        theme.appSorting = .name
        theme.showAppIcons = true
        
        // Reset app settings
        settings.resetToDefaults()
        Task {
            _ = await AISettings.shared.eraseAllData()
        }
        
        print("All settings reset to defaults")
    }
    
    private func installUUIDProfile() {
        let profileXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadUUID</key>
            <string>" + UUID().uuidString.uppercased() + "</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadOrganization</key>
            <string>FreeSign</string>
            <key>PayloadIdentifier</key>
            <string>com.freesign.uuid-profile</string>
            <key>PayloadDisplayName</key>
            <string>FreeSign UUID</string>
            <key>PayloadDescription</key>
            <string>Extracts device UUID for FreeSign</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadUUID</key>
                    <string>" + UUID().uuidString.uppercased() + "</string>
                    <key>PayloadType</key>
                    <string>com.apple.mdm</string>
                    <key>PayloadIdentifier</key>
                    <string>com.freesign.uuid-payload</string>
                    <key>PayloadDisplayName</key>
                    <string>UUID Extraction</string>
                    <key>PayloadDescription</key>
                    <string>Requests device UUID</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                    <key>UDID</key>
                    <true/>
                </dict>
            </array>
        </dict>
        </plist>
        """
        
        let data = profileXML.data(using: .utf8)!
        let base64 = data.base64EncodedString()
        let dataURL = "data:application/x-apple-aspen-config;base64," + base64
        
        if let url = URL(string: dataURL) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.disabledText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - About Row

struct AboutRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
            Spacer()
            Text(value)
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Link Row

struct LinkRow: View {
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                    .font(AppFont.body)
                    .foregroundColor(ThemeManager.shared.accentColor)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ThemeManager.shared.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(AppFont.largeTitle)
                .foregroundColor(AppColors.primaryText)
            
            Text(label)
                .font(AppFont.small)
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ThemeManager.shared.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }
}
