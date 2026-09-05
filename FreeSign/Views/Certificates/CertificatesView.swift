import SwiftUI
import UniformTypeIdentifiers

// MARK: - CertificatesView

struct CertificatesView: View {
    @StateObject private var dataManager  = AppDataManager.shared
    var embeddedInSettings: Bool = false

    // Single file picker — tracks which import type is in progress
    enum PickerMode { case p12, mobileprovision }
    @State private var showFilePicker     = false
    @State private var pickerMode: PickerMode = .p12

    @State private var pendingP12URL: URL?
    @State private var isImporting        = false
    @State private var importStatus       = ""
    @State private var importError: String?
    @State private var showImportError    = false
    @State private var selectedCertID: UUID?

    // Use specific UTTypes for each file type to ensure proper file selection
    private var p12ContentTypes: [UTType] {
        // UTTypes are optional — identifiers like "com.microsoft.pfx" are not
        // guaranteed to resolve on every OS version. Never force-unwrap here;
        // compactMap drops any identifier that fails to resolve.
        [
            UTType("com.rsa.pkcs-12"),
            UTType("com.microsoft.pfx"),
            UTType(filenameExtension: "p12"),
            UTType(filenameExtension: "pfx"),
            .data
        ].compactMap { $0 }
    }
    
    private var mobileProvisionContentTypes: [UTType] {
        [
            UTType("com.apple.mobileprovision"),
            UTType(filenameExtension: "mobileprovision"),
            .data
        ].compactMap { $0 }
    }

    var body: some View {
        certificateContent
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: pickerMode == .p12 ? p12ContentTypes : mobileProvisionContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
            .sheet(isPresented: Binding(
                get: { pendingP12URL != nil },
                set: { if !$0 { pendingP12URL = nil } }
            )) {
                if let url = pendingP12URL {
                    P12PasswordEntryView(
                        fileName: url.lastPathComponent,
                        onCancel: {
                            try? FileManager.default.removeItem(at: url)
                        },
                        onImport: { password in
                            importP12(fromLocalURL: url, password: password)
                        }
                    )
                }
            }
            .alert("Import Failed", isPresented: $showImportError, presenting: importError) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in Text(msg) }
    }

    @ViewBuilder
    private var certificateContent: some View {
        // This view is pushed from Settings as well as presented directly.
        // Keep its title and toolbar in both cases so an existing certificate
        // never hides the Import P12 / Add Profile controls.
        certificatesContent
            .appNavigationTitle("Certificates")
            .appNavigationStyle()
            .toolbar { toolbarContent }
    }

    private var certificatesContent: some View {
        ZStack {
            Group {
                if dataManager.certificates.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.shield",
                        title: "No Certificates",
                        message: "Import a .p12 certificate and a\n.mobileprovision profile to start signing.",
                        actionTitle: "Import P12",
                        action: { openPicker(.p12) }
                    )
                } else {
                    certificateList
                }
            }

            if isImporting {
                LoadingOverlay(message: importStatus.isEmpty ? "Importing…" : importStatus)
            }
        }
    }

    // MARK: - Assistant

    private var certificatesAssistantSummary: String {
        let certs = dataManager.certificates.count
        let validCerts = dataManager.certificates.filter { !$0.isExpired }.count
        let profileCount = dataManager.certificates.flatMap { $0.provisioningProfiles }.count
        return "Certificates view: \(certs) certificate(s), \(validCerts) valid, \(profileCount) provisioning profile(s)."
    }

    // MARK: - Open picker helper

    private func openPicker(_ mode: PickerMode) {
        pickerMode    = mode
        showFilePicker = true
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                openPicker(.p12)
            } label: {
                Label("Import P12 Certificate", systemImage: "key.fill")
            }
            .accessibilityIdentifier("certificates.importP12")
        }
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    openPicker(.p12)
                } label: {
                    Label("Import P12 Certificate", systemImage: "key.fill")
                }
                if !dataManager.certificates.isEmpty {
                    Button {
                        selectedCertID = dataManager.certificates.first?.id
                        openPicker(.mobileprovision)
                    } label: {
                        Label("Add Provisioning Profile", systemImage: "doc.text.badge.plus")
                    }
                    .accessibilityIdentifier("certificates.importProfile")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            TabAssistantButton(sourceView: "Certificates", summary: certificatesAssistantSummary)
        }
    }

    // MARK: - Certificate List

    private var certificateList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(dataManager.certificates) { cert in
                    CertificateCard(
                        cert: cert,
                        onAddProfile: {
                            selectedCertID  = cert.id
                            pickerMode = .mobileprovision
                            showFilePicker = true
                        },
                        onDelete: {
                            withAnimation { dataManager.removeCertificate(cert) }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
    }

    // MARK: - Unified Picker Handler

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            let code = (e as NSError).code
            // -1 = user cancelled in UIDocumentPickerViewController; ignore it
            if code != NSUserCancelledError && code != -1 {
                showError("Could not open file: \(e.localizedDescription)")
            }

        case .success(let urls):
            guard let url = urls.first else { return }

            switch pickerMode {
            case .p12:
                // Validate extension – we accept .data so the picker shows all files
                let ext = url.pathExtension.lowercased()
                guard ext == "p12" || ext == "pfx" else {
                    showError("Please select a .p12 or .pfx certificate file.")
                    return
                }
                
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                
                do {
                    let tempCertURL = try StorageManager.shared.storeP12(from: url)
                    // The sheet is driven by pendingP12URL != nil and queues
                    // until the document picker finishes dismissing.
                    pendingP12URL = tempCertURL
                } catch {
                    showError("Failed to copy certificate to sandbox: \(error.localizedDescription)")
                }

            case .mobileprovision:
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                
                do {
                    let localURL = try StorageManager.shared.storeMobileProvision(from: url)
                    importProvisioningProfile(fromLocalURL: localURL)
                } catch {
                    showError("Failed to copy provisioning profile to sandbox: \(error.localizedDescription)")
                }
            }
        }
    }

    private func importP12(fromLocalURL url: URL, password: String) {
        // All P12/PFX routes use FileImporter so certificate passphrases are
        // handled consistently and stored in Keychain rather than metadata.
        FileImporter.shared.importCertificate(fromLocalURL: url, password: password)
    }

    // MARK: - Provisioning Profile Import

    private func importProvisioningProfile(fromLocalURL url: URL) {
        isImporting  = true
        importStatus = "Reading profile…"

        Task.detached(priority: .userInitiated) {
            do {
                let profile = try ProvisioningProfileParser.parse(at: url.path)

                // Attach to selected cert or the first valid one
                let targetID = await MainActor.run {
                    selectedCertID
                        ?? AppDataManager.shared.certificates.first { !$0.isExpired }?.id
                        ?? AppDataManager.shared.certificates.first?.id
                }

                await MainActor.run {
                    if let id = targetID {
                        AppDataManager.shared.addProfile(profile, toCertificate: id)
                        isImporting = false
                    } else {
                        isImporting = false
                        // No certificate exists to attach the profile to — surface
                        // it instead of silently dropping the import.
                        try? FileManager.default.removeItem(at: url)
                        showError("Import a .p12 certificate first, then add provisioning profiles.")
                    }
                }

            } catch {
                try? FileManager.default.removeItem(at: url)
                
                await MainActor.run {
                    isImporting = false
                    showError("Failed to import profile: \(error.localizedDescription)")
                }
            }
        }
    }


    // MARK: - Error

    private func showError(_ msg: String) {
        importError    = msg
        showImportError = true
    }
}

// MARK: - Import Errors

// Using shared ProvisioningProfileParser.ProfileError

// MARK: - Certificate Card

struct CertificateCard: View {
    let cert: Certificate
    let onAddProfile: () -> Void
    let onDelete: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header row ──────────────────────────────────────────────────────
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    // Status icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(expiryColor.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: cert.isExpired ? "xmark.shield" : "checkmark.shield")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(expiryColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(cert.name)
                                .font(AppFont.headline)
                                .foregroundColor(AppColors.primaryText)
                                .lineLimit(1)
                            if cert.isExpired {
                                StatusBadge(text: "EXPIRED", color: AppColors.destructive, filled: true)
                            } else if cert.daysUntilExpiry < 14 {
                                StatusBadge(text: "EXPIRING", color: AppColors.warning)
                            }
                        }
                        HStack(spacing: 10) {
                            Label(cert.teamID.isEmpty ? "—" : cert.teamID,
                                  systemImage: "person.badge.key")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                            Label(cert.certType.displayName, systemImage: cert.certType.iconName)
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Text("Expires \(cert.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.disabledText)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.disabledText)
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())

            // ── Expanded: provisioning profiles ────────────────────────────────
            if isExpanded {
                VStack(spacing: 0) {
                    AppDivider(leadingPadding: 14)

                    if cert.provisioningProfiles.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.disabledText)
                            Text("No provisioning profiles attached")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.disabledText)
                            Spacer()
                            Button(action: onAddProfile) {
                                Label("Add", systemImage: "plus")
                                    .font(AppFont.caption)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(cert.provisioningProfiles) { profile in
                            ProvisioningProfileRow(profile: profile)
                            if profile.id != cert.provisioningProfiles.last?.id {
                                AppDivider(leadingPadding: 14)
                            }
                        }

                        AppDivider(leadingPadding: 14)
                        Button(action: onAddProfile) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 13))
                                Text("Add Profile")
                                    .font(AppFont.caption)
                            }
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var expiryColor: Color {
        AppColors.expiryColor(daysLeft: cert.daysUntilExpiry)
    }
}

// MARK: - Provisioning Profile Row

struct ProvisioningProfileRow: View {
    let profile: ProvisioningProfile

    var body: some View {
        HStack(spacing: 12) {
            AccentIconBackground(
                systemName: "doc.text",
                size: 32, iconSize: 14,
                color: profile.isExpired ? AppColors.destructive : AppColors.secondaryText
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(profile.bundleID)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    if profile.isWildcard {
                        StatusBadge(text: "Wildcard", color: AppColors.gold)
                    }
                    if profile.isExpired {
                        StatusBadge(text: "Expired", color: AppColors.destructive, filled: true)
                    }
                }
            }

            Spacer()

            Text("Exp. \(profile.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                .font(AppFont.small)
                .foregroundColor(AppColors.disabledText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - P12 Password Entry Sheet

/// Small sheet shown after picking a .p12 from the Files app.
/// Presented as a sheet (not an alert) so it reliably appears after the
/// document picker finishes dismissing.
struct P12PasswordEntryView: View {
    let fileName: String
    let onCancel: () -> Void
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ThemeManager.shared.accentColor.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "key.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ThemeManager.shared.accentColor)
                }

                Text("Certificate Password")
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)

                Text(fileName)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                SecureField("Password (leave blank if none)", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                    .submitLabel(.done)
                    .onSubmit { importAction() }
                    .padding(.horizontal, 24)

                Text("Passwordless certificates work with an empty password.")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.disabledText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: importAction)
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeManager.shared.accentColor)
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func importAction() {
        let pw = password
        onImport(pw)
        dismiss()
    }
}

#Preview {
    NavigationStack { CertificatesView() }
}
