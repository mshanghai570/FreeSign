import SwiftUI

// MARK: - Signing Options View

/// A comprehensive view showing all configurable signing options as toggles and pickers.
/// Mirrors Feather's SigningOptionsView, adapted for FreeSigniOS's card-based UI.
struct SigningOptionsView: View {
    @Binding var options: Options
    var temporaryOptions: Options?

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Protection section (only shown when not temporary)
            if temporaryOptions == nil {
                protectionSection
            }

            // General section
            generalSection

            // Signing Type section
            signingTypeSection

            // Tweaks section (only shown when not temporary)
            if temporaryOptions == nil {
                tweaksSection
            }

            // App Features section
            appFeaturesSection

            // Removal section
            removalSection

            // Force Localize section
            forceLocalizeSection

            // Post Signing section
            postSigningSection

            // Experiments section
            experimentsSection
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Protection

    private var protectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protection")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                toggle(
                    "PPQ Protection",
                    systemImage: "shield",
                    isOn: $options.ppqProtection,
                    temporaryValue: temporaryOptions?.ppqProtection,
                    subtitle: "Append a random string to bundle IDs to prevent Apple ID flagging"
                )
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                PickerRow(
                    icon: "paintpalette",
                    title: "Appearance",
                    selection: Binding(
                        get: { options.appAppearance.localizedDescription },
                        set: { newValue in
                            if let val = Options.AppAppearance(rawValue: newValue) {
                                options.appAppearance = val
                            }
                        }
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
                        get: { options.minimumAppRequirement.localizedDescription },
                        set: { newValue in
                            if let val = Options.MinimumAppRequirement(rawValue: newValue) {
                                options.minimumAppRequirement = val
                            }
                        }
                    ),
                    options: Options.MinimumAppRequirement.allCases.map {
                        PickerOption(title: $0.localizedDescription, value: $0.rawValue)
                    }
                )
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Signing Type

    private var signingTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signing Type")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                PickerRow(
                    icon: "signature",
                    title: "Signing Option",
                    selection: Binding(
                        get: { options.signingOption.localizedDescription },
                        set: { newValue in
                            if let val = Options.SigningOption(rawValue: newValue) {
                                options.signingOption = val
                            }
                        }
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
    }

    // MARK: - Tweaks

    private var tweaksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tweaks")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                PickerRow(
                    icon: "doc.badge.gearshape",
                    title: "Injection Path",
                    selection: Binding(
                        get: { options.injectPath.rawValue },
                        set: { newValue in
                            if let val = Options.InjectPath(rawValue: newValue) {
                                options.injectPath = val
                            }
                        }
                    ),
                    options: Options.InjectPath.allCases.map {
                        PickerOption(title: $0.rawValue, value: $0.rawValue)
                    }
                )

                AppDivider(leadingPadding: 52)

                PickerRow(
                    icon: "folder.badge.gearshape",
                    title: "Injection Folder",
                    selection: Binding(
                        get: { options.injectFolder.rawValue },
                        set: { newValue in
                            if let val = Options.InjectFolder(rawValue: newValue) {
                                options.injectFolder = val
                            }
                        }
                    ),
                    options: Options.InjectFolder.allCases.map {
                        PickerOption(title: $0.rawValue, value: $0.rawValue)
                    }
                )

                AppDivider(leadingPadding: 52)

                toggle(
                    "Inject into Extensions",
                    systemImage: "syringe",
                    isOn: $options.injectIntoExtensions,
                    temporaryValue: temporaryOptions?.injectIntoExtensions
                )
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - App Features

    private var appFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Features")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                toggle("File Sharing",       systemImage: "folder.badge.person.crop", isOn: $options.fileSharing,          temporaryValue: temporaryOptions?.fileSharing)
                AppDivider(leadingPadding: 52)
                toggle("iTunes File Sharing", systemImage: "music.note.list",       isOn: $options.itunesFileSharing,     temporaryValue: temporaryOptions?.itunesFileSharing)
                AppDivider(leadingPadding: 52)
                toggle("Pro Motion",          systemImage: "speedometer",              isOn: $options.proMotion,             temporaryValue: temporaryOptions?.proMotion)
                AppDivider(leadingPadding: 52)
                toggle("Game Mode",           systemImage: "gamecontroller",          isOn: $options.gameMode,              temporaryValue: temporaryOptions?.gameMode)
                AppDivider(leadingPadding: 52)
                toggle("iPad Fullscreen",     systemImage: "ipad.landscape",          isOn: $options.ipadFullscreen,        temporaryValue: temporaryOptions?.ipadFullscreen)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Removal

    private var removalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Removal")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                toggle("Remove URL Schemes",  systemImage: "ellipsis.curlybraces",     isOn: $options.removeURLScheme, temporaryValue: temporaryOptions?.removeURLScheme)
                AppDivider(leadingPadding: 52)
                toggle("Remove Provisioning", systemImage: "doc.badge.gearshape",      isOn: $options.removeProvisioning, temporaryValue: temporaryOptions?.removeProvisioning)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Force Localize

    private var forceLocalizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Localization")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                toggle(
                    "Force Localize",
                    systemImage: "character.bubble",
                    isOn: $options.changeLanguageFilesForCustomDisplayName,
                    temporaryValue: temporaryOptions?.changeLanguageFilesForCustomDisplayName,
                    subtitle: "Override localized titles for custom display name"
                )
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Post Signing

    private var postSigningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post Signing")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                toggle("Install After Signing", systemImage: "arrow.down.circle", isOn: $options.post_installAppAfterSigned, temporaryValue: temporaryOptions?.post_installAppAfterSigned)
                AppDivider(leadingPadding: 52)
                toggle("Delete After Signing",  systemImage: "trash",               isOn: $options.post_deleteAppAfterSigned, temporaryValue: temporaryOptions?.post_deleteAppAfterSigned, subtitle: "Delete the imported app after signing to save space")
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Experiments

    private var experimentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Experiments")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                toggle("Replace Substrate with ElleKit", systemImage: "pencil", isOn: $options.experiment_replaceSubstrateWithEllekit, temporaryValue: temporaryOptions?.experiment_replaceSubstrateWithEllekit)

                AppDivider(leadingPadding: 52)

                toggle("Disable Liquid Glass", systemImage: "18.circle", isOn: $options.experiment_disableLiquidGlass, temporaryValue: temporaryOptions?.experiment_disableLiquidGlass)
                    .disabled(options.experiment_supportLiquidGlass)

                AppDivider(leadingPadding: 52)

                toggle("Enable Liquid Glass", systemImage: "26.circle", isOn: $options.experiment_supportLiquidGlass, temporaryValue: temporaryOptions?.experiment_supportLiquidGlass)
                    .disabled(options.experiment_disableLiquidGlass)
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Toggle Helper

    @ViewBuilder
    private func toggle(
        _ title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        temporaryValue: Bool? = nil,
        subtitle: String = ""
    ) -> some View {
        Toggle(isOn: isOn) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    if let temp = temporaryValue, temp != isOn.wrappedValue {
                        Text(title).bold()
                    } else {
                        Text(title)
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .toggleStyle(SwitchToggleStyle())
        .tint(AppColors.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            SigningOptionsView(options: .constant(Options.defaultOptions))
        }
        .background(AppColors.background)
        .navigationTitle("Signing Options")
        .navigationBarTitleDisplayMode(.inline)
    }
}
