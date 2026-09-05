import SwiftUI
import UniformTypeIdentifiers

struct AssistantSettingsView: View {
    @State private var showingAddProvider = false
    @State private var editingProvider: AIProviderConfiguration?
    @State private var showingAPIKeyInput = false
    @State private var selectedProviderForAPIKey: AIProviderConfiguration?
    @State private var apiKeyInput = ""
    @State private var apiKeyStatusMessage: String?
    @State private var showingModelImporter = false
    @State private var showingQuickAPIKeyInput = false
    @State private var testingProviderID: UUID?
    @State private var providerTestMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !AISettings.shared.hasActiveProvider {
                    inactiveBanner
                }

                // Direct API Key Input Section
                directAPIKeySection

                providersList

                addProviderButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(ThemeManager.shared.backgroundView)
        .appNavigationTitle("Lab Assistant")
        .appNavigationStyle()
        .sheet(isPresented: $showingAddProvider) {
            ProviderEditView(
                provider: editingProvider,
                onSave: { config in
                    if let existing = editingProvider {
                        AISettings.shared.updateProvider(config)
                    } else {
                        AISettings.shared.addProvider(config)
                    }
                    AISettings.shared.save()
                    editingProvider = nil
                },
                onCancel: {
                    editingProvider = nil
                }
            )
        }
        .sheet(isPresented: $showingAPIKeyInput, onDismiss: {
            apiKeyStatusMessage = nil
        }) {
            APIKeyInputView(
                provider: selectedProviderForAPIKey,
                apiKey: $apiKeyInput,
                statusMessage: $apiKeyStatusMessage,
                onSave: { key in
                    guard let provider = selectedProviderForAPIKey else { return }
                    Task {
                        let success = await KeychainHelper.save(providerID: provider.id, apiKey: key)
                        await MainActor.run {
                            apiKeyStatusMessage = success ? "API key saved." : "Failed to save API key."
                            if success {
                                AIService.shared.refreshActiveProvider()
                            }
                        }
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $showingModelImporter,
            allowedContentTypes: [
                UTType("com.freesign.local-model"),
                UTType(filenameExtension: "gguf"),
                UTType(filenameExtension: "mlx"),
                UTType(filenameExtension: "safetensors")
            ].compactMap { $0 },
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .failure(let error):
                let code = (error as NSError).code
                if code != NSUserCancelledError && code != -1 {
                    print("Model import failed: \(error.localizedDescription)")
                }
            case .success(let urls):
                for url in urls {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    do {
                        _ = try StorageManager.shared.storeLocalModel(from: url)
                    } catch {
                        print("Failed to import model \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }
            .onAppear {
                AIService.shared.refreshActiveProvider()
            }
            .alert("Provider Connection", isPresented: Binding(
                get: { providerTestMessage != nil },
                set: { if !$0 { providerTestMessage = nil } }
            )) {
                Button("OK", role: .cancel) { providerTestMessage = nil }
            } message: {
                Text(providerTestMessage ?? "")
            }
    }

    private var inactiveBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.warning)
                Text("No active provider")
                    .font(AppFont.body.bold())
                    .foregroundColor(AppColors.primaryText)
            }
            Text("Add and activate an AI provider to use the Lab Assistant.")
                .font(AppFont.small)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.warning.opacity(0.4), lineWidth: 1)
        )
    }

    private var directAPIKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick API Key Setup")
                    .font(AppFont.title)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                Button {
                    showingQuickAPIKeyInput.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add API Key")
                    }
                    .font(AppFont.caption.bold())
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 4)
            
            if !AISettings.shared.providerConfigs.isEmpty {
                VStack(spacing: 1) {
                    ForEach(AISettings.shared.providerConfigs.filter { config in
                        // Only show providers that have API keys stored
                        if let storedKey = KeychainHelper.loadSync(providerID: config.id), !storedKey.isEmpty {
                            return true
                        }
                        return false
                    }) { config in
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: config.providerType.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(config.isActive ? AppColors.success : AppColors.accent)
                                    .frame(width: 20)
                                
                                Text(config.name)
                                    .font(AppFont.body)
                                    .foregroundColor(AppColors.primaryText)
                                
                                Spacer()
                                
                                Text("API Key: ••••••")
                                    .font(AppFont.small)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            
                            Divider()
                                .background(AppColors.cardBorder)
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "key")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.disabledText)
                    Text("No API keys configured")
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                    Text("Add your first AI provider API key to get started")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
            }
        }
        .sheet(isPresented: $showingQuickAPIKeyInput) {
            QuickAPIKeyInputView(
                onSave: { providerName, providerType, apiKey in
                    let config = AIProviderConfiguration(
                        id: UUID(),
                        name: providerName,
                        providerType: providerType,
                        endpointURL: providerType.defaultEndpoint,
                        modelName: providerType.defaultModel
                    )
                    
                    Task {
                        let success = await KeychainHelper.save(providerID: config.id, apiKey: apiKey)
                        if success {
                            AISettings.shared.addProvider(config)
                            AISettings.shared.setActiveProvider(id: config.id)
                            AISettings.shared.save()
                            AIService.shared.refreshActiveProvider()
                        }
                    }
                }
            )
        }
    }

    private var providersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Providers")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 4)

            if AISettings.shared.providerConfigs.isEmpty {
                emptyProvidersState
            } else {
                ForEach(AISettings.shared.providerConfigs) { config in
                    providerRow(for: config)
                }
            }
        }
    }

    private var emptyProvidersState: some View {
        VStack(spacing: 12) {
            Text("No providers configured yet.")
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
            Text("Add a provider below to get started.")
                .font(AppFont.small)
                .foregroundColor(AppColors.disabledText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func providerRow(for config: AIProviderConfiguration) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: config.providerType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(config.isActive ? AppColors.success : AppColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                    Text(config.providerType.displayName)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                    if !config.modelName.isEmpty {
                        Text("Model: \(config.modelName)")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.disabledText)
                    }
                }

                Spacer()

                if config.isActive {
                    Text("Active")
                        .font(AppFont.caption.bold())
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.success.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(14)

            Divider()
                .background(AppColors.cardBorder)

            HStack(spacing: 10) {
                Button {
                    selectedProviderForAPIKey = config
                    apiKeyInput = ""
                    showingAPIKeyInput = true
                } label: {
                    Label("Set API Key", systemImage: "key")
                        .font(AppFont.caption.bold())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.accent.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.accent.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())

                Button {
                    testConnection(for: config)
                } label: {
                    Label("Test Connection", systemImage: testingProviderID == config.id ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .font(AppFont.caption.bold())
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppColors.accent.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(testingProviderID != nil)
                .accessibilityLabel("Test \(config.name) connection")

                Spacer(minLength: 0)

                Menu {
                    Button {
                        selectedProviderForAPIKey = config
                        apiKeyInput = ""
                        showingAPIKeyInput = true
                    } label: {
                        Label("Set API Key", systemImage: "key")
                    }

                    Button {
                        AISettings.shared.setActiveProvider(id: config.id)
                        AIService.shared.refreshActiveProvider()
                    } label: {
                        Label(config.isActive ? "Deactivate" : "Activate", systemImage: config.isActive ? "xmark.circle" : "checkmark.circle")
                    }

                    Button {
                        editingProvider = config
                        showingAddProvider = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        Task {
                            await KeychainHelper.delete(providerID: config.id)
                            AISettings.shared.deleteProvider(id: config.id)
                            AIService.shared.refreshActiveProvider()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.disabledText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if config.endpointURL.isEmpty && config.providerType.requiresEndpoint {
                Text("Endpoint not configured.")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(config.isActive ? AppColors.success.opacity(0.4) : AppColors.cardBorder, lineWidth: 1)
        )
    }

    private func testConnection(for config: AIProviderConfiguration) {
        guard testingProviderID == nil else { return }
        testingProviderID = config.id
        Task {
            do {
                _ = try await AIService.shared.testConnection(for: config)
                await MainActor.run {
                    providerTestMessage = "Connection to \(config.name) succeeded."
                    testingProviderID = nil
                }
            } catch {
                await MainActor.run {
                    providerTestMessage = "Connection to \(config.name) failed: \(error.localizedDescription)"
                    testingProviderID = nil
                }
            }
        }
    }

    private var addProviderButton: some View {
        Button {
            editingProvider = nil
            showingAddProvider = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add Provider")
            }
            .font(AppFont.body.bold())
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

struct APIKeyInputView: View {
    let provider: AIProviderConfiguration?
    @Binding var apiKey: String
    @Binding var statusMessage: String?
    let onSave: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isSecure = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key for \(provider?.name ?? "Provider")")
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)

                    HStack {
                        if isSecure {
                            SecureField("Enter API key...", text: $apiKey)
                        } else {
                            TextField("Enter API key...", text: $apiKey)
                        }
                        Button {
                            isSecure.toggle()
                        } label: {
                            Image(systemName: isSecure ? "eye" : "eye.slash")
                                .foregroundColor(AppColors.disabledText)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal, 16)

                if let message = statusMessage {
                    Text(message)
                        .font(AppFont.small)
                        .foregroundColor(message.contains("Failed") ? AppColors.destructive : AppColors.success)
                        .padding(.horizontal, 16)
                }

                Text("Your API key is stored securely in the iOS Keychain and never shared.")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.disabledText)
                    .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 16)
            .background(AppColors.background)
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(apiKey)
                        dismiss()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

struct ProviderEditView: View {
    let provider: AIProviderConfiguration?
    let onSave: (AIProviderConfiguration) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var providerType: AIProviderType
    @State private var endpointURL: String
    @State private var modelName: String
    @State private var apiKey: String
    @State private var isSecureAPIKey = true
    @State private var selectedModelPath: String?
    @State private var showingModelImporter = false

    init(
        provider: AIProviderConfiguration?,
        onSave: @escaping (AIProviderConfiguration) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.provider = provider
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: provider?.name ?? "")
        _providerType = State(initialValue: provider?.providerType ?? .openAICompatible)
        _endpointURL = State(initialValue: provider?.endpointURL ?? "")
        _modelName = State(initialValue: provider?.modelName ?? "")
        _apiKey = State(initialValue: "")
        _selectedModelPath = State(initialValue: provider?.localModelPath)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $providerType) {
                        ForEach(AIProviderType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if providerType.requiresEndpoint {
                    Section {
                        TextField("Endpoint URL", text: $endpointURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Model Name", text: $modelName)
                        if providerType == .localModel {
                            Text("Point this at your local inference server, e.g. http://192.168.1.10:8080 for a llama.cpp server or Ollama.")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    } header: {
                        Text("Connection")
                    }
                }

                Section {
                    HStack {
                        if isSecureAPIKey {
                            SecureField("API key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            TextField("API key", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button {
                            isSecureAPIKey.toggle()
                        } label: {
                            Image(systemName: isSecureAPIKey ? "eye" : "eye.slash")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text(providerType == .localModel
                         ? "Optional for local servers that don't require authentication."
                         : "Stored securely in the iOS Keychain and never shared.")
                }

                if providerType == .localModel {
                    Section {
                        HStack {
                            Picker("Model File", selection: $selectedModelPath) {
                                Text("None").tag(String?.none)
                                ForEach(importedModelFiles, id: \.self) { url in
                                    Text(url.lastPathComponent).tag(String?.some(url.path))
                                }
                            }
                            .pickerStyle(.menu)

                            Button {
                                showingModelImporter = true
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.accent)
                            }
                        }

                        if let path = selectedModelPath {
                            let url = URL(fileURLWithPath: path)
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(AppColors.info)
                                Text(StorageManager.formattedSize(StorageManager.shared.fileSize(at: path)))
                                    .font(AppFont.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                Spacer()
                                if let type = url.pathExtension.uppercased().isEmpty ? nil : url.pathExtension.uppercased() {
                                    Text(type)
                                        .font(AppFont.caption.bold())
                                        .foregroundColor(AppColors.info)
                                }
                            }
                        }

                        Text("Pick a GGUF or MLX model imported into FreeSign. Its file name is sent as the model to your local server; override with Model Name above if needed.")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                    } header: {
                        Text("Local Model File")
                    }
                }

                Section {
                Button("Save Provider") {
                    let config = AIProviderConfiguration(
                        id: provider?.id ?? UUID(),
                        name: name,
                        providerType: providerType,
                        endpointURL: endpointURL,
                        modelName: modelName,
                        isActive: provider?.isActive ?? false,
                        localModelPath: providerType == .localModel ? selectedModelPath : nil
                    )
                    let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        if !trimmedKey.isEmpty {
                            await KeychainHelper.save(providerID: config.id, apiKey: trimmedKey)
                        }
                        onSave(config)
                        AIService.shared.refreshActiveProvider()
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(provider == nil ? "New Provider" : "Edit Provider")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showingModelImporter,
                allowedContentTypes: [
                    UTType("com.freesign.local-model"),
                    UTType(filenameExtension: "gguf"),
                    UTType(filenameExtension: "mlx"),
                    UTType(filenameExtension: "safetensors")
                ].compactMap { $0 },
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .failure(let error):
                    let code = (error as NSError).code
                    if code != NSUserCancelledError && code != -1 {
                        print("Model import failed: \(error.localizedDescription)")
                    }
                case .success(let urls):
                    for url in urls {
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        do {
                            _ = try StorageManager.shared.storeLocalModel(from: url)
                        } catch {
                            print("Failed to import model \(url.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard let provider = provider else { return }
                Task {
                    let storedKey = await KeychainHelper.load(providerID: provider.id) ?? ""
                    await MainActor.run {
                        apiKey = storedKey
                    }
                }
            }
        }
    }

    /// Imported GGUF/MLX files available to the Local Model provider.
    private var importedModelFiles: [URL] {
        StorageManager.shared.localModelFiles()
    }
}

struct QuickAPIKeyInputView: View {
    let onSave: (String, AIProviderType, String) -> Void
    
    @Environment(\dismiss) var dismiss
    @State private var providerName = ""
    @State private var providerType: AIProviderType = .openAICompatible
    @State private var apiKey = ""
    @State private var isSecure = true
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    TextField("Provider Name", text: $providerName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    
                    Picker("Provider Type", selection: $providerType) {
                        ForEach(AIProviderType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("API Key") {
                    HStack {
                        if isSecure {
                            SecureField("API key", text: $apiKey)
                        } else {
                            TextField("API key", text: $apiKey)
                        }
                        Button {
                            isSecure.toggle()
                        } label: {
                            Image(systemName: isSecure ? "eye" : "eye.slash")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    
                    Text("Your API key is stored securely in the iOS Keychain and never shared.")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
                
                Section {
                    Button {
                        isSaving = true
                        onSave(providerName, providerType, apiKey)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(AppColors.accent)
                            } else {
                                Text("Save API Key")
                            }
                            Spacer()
                        }
                    }
                    .disabled(providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(AppColors.accent)
                }
            }
            .navigationTitle("Add API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AssistantSettingsView()
    }
}
