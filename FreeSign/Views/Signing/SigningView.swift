import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Signing View

/// The main signing interface. Integrates Feather-style signing options
/// (PPQ protection, dictionary-based name/ID replacement, tweaks, entitlements)
/// with FreeSigniOS's existing card-based UI.
struct SigningView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var dataManager = AppDataManager.shared
    @StateObject private var signingManager = SigningManager.shared
    @StateObject private var optionsManager = OptionsManager.shared

    // Temporary options initialized from the global OptionsManager — changes here
    // do NOT persist until the user explicitly saves from ConfigurationView.
    @State private var temporaryOptions: Options = OptionsManager.shared.options

    let app: AppInfo

    // MARK: - UI State

    @State private var selectedCertIndex: Int = 0
    @State private var showCertPicker = false
    @State private var showTweaks = false
    @State private var showEntitlements = false
    @State private var showPropertiesEditor = false
    @State private var animateContent = false

    // App icon override (nil = use the app's original icon)
    @State private var appIcon: UIImage?
    @State private var isAltPickerPresenting = false
    @State private var isFilePickerPresenting = false
    @State private var isImagePickerPresenting = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var entitlementsFile: URL?

    // MARK: - Computed

    var selectedCertificate: Certificate? {
        guard dataManager.certificates.indices.contains(selectedCertIndex) else { return nil }
        return dataManager.certificates[selectedCertIndex]
    }

    // Resolve the display name after applying dictionary rules
    private var effectiveAppName: String {
        temporaryOptions.displayNames[app.name] ?? app.name
    }

    // Resolve the bundle ID after applying dictionary rules + PPQ
    private var effectiveBundleID: String {
        var id = temporaryOptions.identifiers[app.bundleID] ?? app.bundleID

        if optionsManager.options.ppqProtection,
           !id.isEmpty,
           let cert = selectedCertificate, cert.teamID.count >= 8 {
            // Feather appends ppqString only when PPQ protection is on
            id = "\(id).\(optionsManager.options.ppqString)"
        }

        if let custom = temporaryOptions.appIdentifier, !custom.isEmpty {
            id = custom
        }
        return id
    }

    // MARK: - Init

    init(app: AppInfo) {
        self.app = app
        let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
        _selectedCertIndex = State(initialValue: storedCert)
    }

    // MARK: - Appear

    private func applyRules() {
        // Apply saved display name replacement
        if let newName = optionsManager.options.displayNames[app.name] {
            temporaryOptions.appName = newName
        }

        // Apply saved identifier replacement
        if let newBundleID = optionsManager.options.identifiers[app.bundleID] {
            temporaryOptions.appIdentifier = newBundleID
        }
    }

    // MARK: - Assistant

    private var signingAssistantSummary: String {
        let certs = dataManager.certificates.count
        let certName = selectedCertificate?.commonName ?? "None"
        let tweaksCount = signingManager.availableTweaks.count
        return "Signing view: \(app.name) (bundle: \(app.bundleID)), "
             + "\(certs) certificate(s) available, selected: \(certName), "
             + "\(tweaksCount) tweak(s) available."
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App Info Header with icon
                appHeader

                // Customization (name, identifier, version)
                customizationSection

                // Customization Properties (appearance, minimum requirement, signing type)
                customizationPropertiesSection

                // Certificate selection
                certificateSection

                // Tweaks / Injection
                tweaksSection

                // Entitlements
                entitlementsSection

                // Advanced options (full SigningOptionsView)
                advancedSection

                // Post-signing options
                postSigningSection

                // Experiments
                experimentsSection

                // Action button
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .scrollDismissesKeyboard(.interactively)
        .appNavigationTitle("Signing")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(AppFont.body.bold())
                .foregroundColor(AppColors.accent)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    temporaryOptions = OptionsManager.shared.options
                    appIcon = nil
                    entitlementsFile = nil
                }
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
            }
            ToolbarItem(placement: .primaryAction) {
                TabAssistantButton(sourceView: "Signing", summary: signingAssistantSummary)
            }
        }
        .overlay {
            if signingManager.isSigning {
                signingOverlay
            }
        }
        .sheet(isPresented: $showCertPicker) {
            CertificatePickerView(selectedIndex: $selectedCertIndex)
        }
        .sheet(isPresented: $showTweaks) {
            NavigationStack {
                SigningTweaksView(options: $temporaryOptions)
            }
        }
        .sheet(isPresented: $showEntitlements) {
            NavigationStack {
                SigningEntitlementsView(bindingValue: $entitlementsFile)
            }
        }
        .sheet(isPresented: $isAltPickerPresenting) {
            // Simplified: use file picker for app icon replacement
            FileImporterRepresentable(
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { urls in
                guard let url = urls.first else { return }
                self.appIcon = UIImage(contentsOfFile: url.path)?.resizeToSquare()
            }
        }
        .fileImporter(
            isPresented: $isFilePickerPresenting,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                self.appIcon = UIImage(contentsOfFile: url.path)?.resizeToSquare()
            }
        }
        .photosPicker(isPresented: $isImagePickerPresenting, selection: $selectedPhoto)
        .onChange(of: selectedPhoto) { newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data)?.resizeToSquare() {
                    await MainActor.run { appIcon = image }
                }
            }
        }
        .onAppear {
            animateContent = true
            applyRules()
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                if let icon = appIcon {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else if let iconPath = app.iconPath, let uiImage = UIImage(contentsOfFile: iconPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.surface)
                        .frame(width: 60, height: 60)
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.accent)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(effectiveAppName)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                HStack(spacing: 8) {
                    Text(effectiveBundleID)
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                    Text("v\(app.version)")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
            }

            Spacer()
        }
        .appCard()
    }

    // MARK: - Customization

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customization")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                // Change app icon
                Button {
                    isAltPickerPresenting = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.surface)
                                .frame(width: 44, height: 44)
                            Image(systemName: "app.dashed")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change App Icon")
                                .font(AppFont.body)
                                .foregroundColor(AppColors.primaryText)
                            Text("Replace the app icon with a custom one")
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
                .buttonStyle(PlainButtonStyle())

                AppDivider(leadingPadding: 52)

                // Display name
                infoCell("Name", desc: temporaryOptions.appName ?? effectiveAppName) {
                    SigningPropertiesView(
                        title: "Name",
                        initialValue: temporaryOptions.appName ?? effectiveAppName,
                        bindingValue: $temporaryOptions.appName
                    )
                }

                AppDivider(leadingPadding: 52)

                // Bundle ID
                infoCell("Identifier", desc: temporaryOptions.appIdentifier ?? effectiveBundleID) {
                    SigningPropertiesView(
                        title: "Identifier",
                        initialValue: temporaryOptions.appIdentifier ?? effectiveBundleID,
                        bindingValue: $temporaryOptions.appIdentifier
                    )
                }

                AppDivider(leadingPadding: 52)

                // Version
                infoCell("Version", desc: temporaryOptions.appVersion ?? app.version) {
                    SigningPropertiesView(
                        title: "Version",
                        initialValue: temporaryOptions.appVersion ?? app.version,
                        bindingValue: $temporaryOptions.appVersion
                    )
                }
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Customization Properties (Appearance, Min Requirement, Signing Type)

    private var customizationPropertiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customization Properties")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                PickerRow(
                    icon: "paintpalette",
                    title: "Appearance",
                    selection: Binding(
                        get: { temporaryOptions.appAppearance.localizedDescription },
                        set: { if let v = Options.AppAppearance(rawValue: $0) { temporaryOptions.appAppearance = v } }
                    ),
                    options: Options.AppAppearance.allCases.map {
                        PickerOption(title: $0.localizedDescription, value: $0.rawValue)
                    }
                )

                AppDivider(leadingPadding: 52)

                PickerRow(
                    icon: "ruler",
                    title: "Minimum Requirement",
                    selection: Binding(
                        get: { temporaryOptions.minimumAppRequirement.localizedDescription },
                        set: { if let v = Options.MinimumAppRequirement(rawValue: $0) { temporaryOptions.minimumAppRequirement = v } }
                    ),
                    options: Options.MinimumAppRequirement.allCases.map {
                        PickerOption(title: $0.localizedDescription, value: $0.rawValue)
                    }
                )

                AppDivider(leadingPadding: 52)

                PickerRow(
                    icon: "signature",
                    title: "Signing Type",
                    selection: Binding(
                        get: { temporaryOptions.signingOption.localizedDescription },
                        set: { if let v = Options.SigningOption(rawValue: $0) { temporaryOptions.signingOption = v } }
                    ),
                    options: Options.SigningOption.allCases.map {
                        PickerOption(title: $0.localizedDescription, value: $0.rawValue)
                    }
                )
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.1), value: animateContent)
    }

    // MARK: - Certificate

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signing Certificate")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            if let cert = selectedCertificate {
                Button(action: { showCertPicker = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cert.isExpired ? Color.red.opacity(0.1) : AppColors.accent.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "certificate")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(cert.isExpired ? AppColors.destructive : AppColors.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cert.name)
                                .font(AppFont.headline)
                                .foregroundColor(AppColors.primaryText)
                                .lineLimit(1)
                            Text("Expires \(cert.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.disabledText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .padding(14)
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
                .buttonStyle(PlainButtonStyle())
            } else {
                Button(action: { showCertPicker = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No Certificate Selected")
                                .font(AppFont.headline)
                                .foregroundColor(AppColors.accent)
                            Text("Tap to select a signing certificate")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .padding(14)
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
                .buttonStyle(PlainButtonStyle())
            }
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.15), value: animateContent)
    }

    // MARK: - Tweaks

    private var tweaksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tweaks & Injection")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            Button {
                showTweaks = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface)
                            .frame(width: 44, height: 44)
                        Image(systemName: "cube.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Tweaks")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                        Text("\(temporaryOptions.injectionFiles.count) file(s) to inject")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.disabledText)
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.2), value: animateContent)
    }

    // MARK: - Entitlements

    private var entitlementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entitlements")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            Button {
                showEntitlements = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface)
                            .frame(width: 44, height: 44)
                        Image(systemName: entitlementsFile != nil ? "doc.text.wrench" : "doc.text.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Entitlements")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                        Text(entitlementsFile?.lastPathComponent ?? "No entitlements file selected")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.disabledText)
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.22), value: animateContent)
    }

    // MARK: - Advanced (Signing Options)

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advanced")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                // Remove App Extensions
                SimpleToggleRow(icon: "puzzlepiece.extension", title: "Remove App Extensions", isOn: $temporaryOptions.removeExtensions)
                AppDivider(leadingPadding: 52)

                // Remove Watch App
                SimpleToggleRow(icon: "applewatch", title: "Remove Watch App", isOn: $temporaryOptions.removeWatchApp)
                AppDivider(leadingPadding: 52)

                // Remove Supported Devices
                SimpleToggleRow(icon: "ipad.landscape", title: "Remove Supported Devices", isOn: $temporaryOptions.removeUISupportedDevices)
                AppDivider(leadingPadding: 52)

                // Enable Documents
                SimpleToggleRow(icon: "doc", title: "Enable Documents", isOn: $temporaryOptions.enableDocuments)
                AppDivider(leadingPadding: 52)

                // Weak Inject Dylibs
                SimpleToggleRow(icon: "cube", title: "Weak Inject Dylibs", isOn: $temporaryOptions.weakInject)
                AppDivider(leadingPadding: 52)

                // Ad-Hoc Signing
                SimpleToggleRow(icon: "checkmark.shield", title: "Ad-Hoc Signing", isOn: $temporaryOptions.isAdhoc)
                AppDivider(leadingPadding: 52)

                // Force Re-Sign
                SimpleToggleRow(icon: "arrow.clockwise", title: "Force Re-Sign", isOn: $temporaryOptions.forceResign)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.25), value: animateContent)
    }

    // MARK: - Post Signing

    private var postSigningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post Signing")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                SimpleToggleRow(icon: "arrow.down.circle", title: "Install After Signing", isOn: $temporaryOptions.installAfterSigning)
                AppDivider(leadingPadding: 52)
                SimpleToggleRow(icon: "square.and.arrow.up", title: "Share After Signing", isOn: $temporaryOptions.shareAfterSigning)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.27), value: animateContent)
    }

    // MARK: - Experiments

    private var experimentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Experiments")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                SimpleToggleRow(icon: "puzzlepiece", title: "Replace Substrate with ElleKit", isOn: $temporaryOptions.experiment_replaceSubstrateWithEllekit)
                AppDivider(leadingPadding: 52)
                SimpleToggleRow(icon: "paintbrush", title: "Enable Liquid Glass", isOn: $temporaryOptions.experiment_supportLiquidGlass)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.28), value: animateContent)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: startSigning) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16))
                Text("Sign & Export")
                    .font(AppFont.button)
            }
        }
        .appPrimaryButton()
        .disabled(signingManager.isSigning || selectedCertificate == nil)
        .opacity((signingManager.isSigning || selectedCertificate == nil) ? 0.5 : 1.0)
        .padding(.top, 8)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.3), value: animateContent)
    }

    // MARK: - Signing Overlay

    private var signingOverlay: some View {
        ZStack {
            AppColors.background.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    ProgressView(value: signingManager.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(AppColors.accent)
                        .frame(height: 6)
                        .scaleEffect(y: 2, anchor: .center)

                    Text(signingManager.statusMessage)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .appCard()
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }

    // MARK: - Info Cell Helper

    @ViewBuilder
    private func infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
        NavigationLink {
            destination()
        } label: {
            LabeledContent(title) {
                Text(desc ?? "Unknown")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .appNavigationTitleStyle()
    }

    // MARK: - Start Signing

    private func startSigning() {
        guard let cert = selectedCertificate else { return }

        // Build SigningOptions from the temporary Options + global dictionary rules
        let signingOpts = SigningOptions(
            appName: temporaryOptions.appName,
            appIdentifier: effectiveBundleID,
            appVersion: temporaryOptions.appVersion,
            isAdhoc: temporaryOptions.isAdhoc,
            forceResign: temporaryOptions.forceResign,
            entitlementsPath: entitlementsFile?.path,
            removeExtensions: temporaryOptions.removeExtensions,
            removeWatchApp: temporaryOptions.removeWatchApp,
            removeUISupportedDevices: temporaryOptions.removeUISupportedDevices,
            enableDocuments: temporaryOptions.enableDocuments,
            injectDylibs: temporaryOptions.injectionFiles.map { $0.path },
            removeDylibs: temporaryOptions.disInjectionFiles,
            weakInject: temporaryOptions.weakInject,
            installAfterSigning: temporaryOptions.installAfterSigning,
            shareAfterSigning: temporaryOptions.shareAfterSigning,
            customPlistEntries: []
        )

        signingManager.signPackage(app, certificate: cert, options: signingOpts, iconOverride: appIcon?.pngData()) { result in
            switch result {
            case .success(let path):
                print("✅ Signed: \(path)")
                dismiss()
            case .failure(let error):
                print("❌ Error: \(error)")
            }
        }
    }
}

// MARK: - FileImporterRepresentable (lightweight wrapper for Photos-style picker)

struct FileImporterRepresentable: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void
        init(onPicked: @escaping ([URL]) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - Navigation Title Style Extension

private extension View {
    func appNavigationTitleStyle() -> some View {
        self
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.separator)
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
        SigningView(app: previewApp)
    }
}
