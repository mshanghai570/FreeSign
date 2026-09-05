import SwiftUI
import UniformTypeIdentifiers

// MARK: - SimplePlistEditorView

struct SimplePlistEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var plistData: [String: Any] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSaveConfirmation = false
    @State private var hasChanges = false
    @State private var searchText = ""
    @State private var expandedKeys: Set<String> = []
    @State private var showAssistantResponse = false
    @State private var assistantResponse = ""
    @State private var assistantContextSummary = ""
    @State private var isAssistantGenerating = false
    @State private var selectedKeyForAssistant: String?
    
    private let plistEncoder = PropertyListEncoder()
    private let plistDecoder = PropertyListDecoder()
    
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.backgroundView
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.warning)
                        Text("Failed to load plist")
                            .font(AppFont.title)
                        Text(error)
                            .font(AppFont.body)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Dismiss") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    plistEditorContent
                }
            }
            .appNavigationTitle(fileURL.lastPathComponent)
            .appNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showSaveConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlist()
                    }
                    .disabled(!hasChanges)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            addNewKey()
                        } label: {
                            Label("Add Key", systemImage: "plus")
                        }

                        Button {
                            expandAll()
                        } label: {
                            Label("Expand All", systemImage: "arrow.down.left.and.arrow.up.right")
                        }

                        Button {
                            collapseAll()
                        } label: {
                            Label("Collapse All", systemImage: "arrow.up.right.and.arrow.down.left")
                        }

                        Divider()

                        Button {
                            runAssistant(action: .explain, keyPath: selectedKeyForAssistant)
                        } label: {
                            Label("Explain Key", systemImage: "text.bubble")
                        }
                        .disabled(selectedKeyForAssistant == nil)

                        Button {
                            runAssistant(action: .analyze, keyPath: nil)
                        } label: {
                            Label("Analyze File", systemImage: "waveform.path")
                        }

                        Button {
                            runAssistant(action: .suggest, keyPath: nil)
                        } label: {
                            Label("Suggest Improvements", systemImage: "lightbulb")
                        }

                        Button {
                            runAssistant(action: .custom, keyPath: nil)
                        } label: {
                            Label("Ask Assistant...", systemImage: "brain")
                        }
                    } label: {
                        Image(systemName: "brain")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search keys...")
            .onAppear {
                loadPlist()
            }
            .alert("Save Changes?", isPresented: $showSaveConfirmation) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Save") { savePlist(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Would you like to save them?")
            }
            .sheet(isPresented: $showAssistantResponse) {
                AssistantResponseView(
                    response: assistantResponse,
                    contextSummary: assistantContextSummary,
                    onContinueInNotebook: {
                        // Future: push to LabConversationView
                    },
                    onDismiss: {
                        assistantResponse = ""
                        assistantContextSummary = ""
                    }
                )
            }
            .overlay {
                if isAssistantGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(AppColors.accent)
                        Text("Assistant is thinking...")
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(20)
                    .background(AppColors.surface.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
    
    // MARK: - Plist Editor Content
    
    @ViewBuilder
    private var plistEditorContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sortedKeys, id: \.self) { key in
                    SimplePlistKeyRow(
                        key: key,
                        value: plistData[key],
                        path: key,
                        expandedKeys: $expandedKeys,
                        searchText: searchText,
                        onChange: { newValue in
                            plistData[key] = newValue
                            hasChanges = true
                        },
                        onDelete: {
                            plistData.removeValue(forKey: key)
                            hasChanges = true
                        },
                        onExplain: {
                            runAssistant(action: .explain, keyPath: key)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
    }
    
    private var sortedKeys: [String] {
        let keys = Array(plistData.keys).sorted()
        if searchText.isEmpty { return keys }
        return keys.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Plist Operations
    
    private func loadPlist() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: fileURL)
                var format = PropertyListSerialization.PropertyListFormat.xml
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
                
                if let dict = plist as? [String: Any] {
                    DispatchQueue.main.async {
                        self.plistData = dict
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Root element is not a dictionary"
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func savePlist() {
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: plistData,
                format: .xml,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
            hasChanges = false
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func addNewKey() {
        var newKey = "NewKey"
        var counter = 1
        while plistData[newKey] != nil {
            newKey = "NewKey\(counter)"
            counter += 1
        }
        plistData[newKey] = ""
        hasChanges = true
        expandedKeys.insert(newKey)
    }
    
    private func expandAll() {
        for key in plistData.keys {
            expandedKeys.insert(key)
        }
    }
    
    private func collapseAll() {
        expandedKeys.removeAll()
    }

    // MARK: - Assistant

    func runAssistant(action: AIAction, keyPath: String?) {
        guard AISettings.shared.hasActiveProvider else {
            assistantResponse = "No AI provider is configured. Open Settings > Lab Assistant to add one."
            assistantContextSummary = "No provider configured"
            showAssistantResponse = true
            return
        }

        selectedKeyForAssistant = keyPath

        let keyPathToUse = keyPath ?? "all keys"
        let valueType: String
        let valuePreview: String

        if let keyPath = keyPath, let value = plistData[keyPath] {
            valueType = typeDisplayName(for: value)
            valuePreview = valuePreviewString(value)
        } else {
            valueType = "mixed"
            valuePreview = ""
        }

        let snippet = plistSnippet(from: plistData, maxKeys: 20)

        let context = PlistEditorContext(
            sourceView: "SimplePlistEditorView",
            action: action,
            filePath: fileURL.path,
            keyPath: keyPathToUse,
            valueType: valueType,
            valuePreview: valuePreview,
            fullPlistSnippet: snippet
        )

        assistantContextSummary = context.summary
        isAssistantGenerating = true
        showAssistantResponse = false

        Task {
            do {
                let stream = try await AIService.shared.respond(to: action, context: context)
                var fullResponse = ""
                for try await chunk in stream {
                    fullResponse += chunk
                }
                await MainActor.run {
                    assistantResponse = fullResponse
                    isAssistantGenerating = false
                    showAssistantResponse = true
                }
            } catch {
                await MainActor.run {
                    assistantResponse = "Error: \(error.localizedDescription)"
                    isAssistantGenerating = false
                    showAssistantResponse = true
                }
            }
        }
    }

    private func typeDisplayName(for value: Any?) -> String {
        guard let value = value else { return "Null" }
        if value is String { return "String" }
        if value is Bool { return "Boolean" }
        if value is Int { return "Integer" }
        if value is Double { return "Real" }
        if value is Date { return "Date" }
        if value is Data { return "Data" }
        if value is [String: Any] { return "Dictionary" }
        if value is [Any] { return "Array" }
        return "Unknown"
    }

    private func valuePreviewString(_ value: Any?) -> String {
        guard let value = value else { return "null" }
        if let str = value as? String { return "\"\(str.prefix(80))\"" }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let int = value as? Int { return "\(int)" }
        if let double = value as? Double { return "\(double)" }
        if let date = value as? Date { return date.formatted() }
        if let data = value as? Data { return "<Data: \(data.count) bytes>" }
        if let dict = value as? [String: Any] { return "{\(dict.count) keys}" }
        if let array = value as? [Any] { return "[\(array.count) items]" }
        return "\(value)"
    }

    private func plistSnippet(from dict: [String: Any], maxKeys: Int) -> String {
        let keys = Array(dict.keys).sorted().prefix(maxKeys)
        var lines: [String] = []
        for key in keys {
            lines.append("\(key): \(valuePreviewString(dict[key]))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Plist Key Row

struct SimplePlistKeyRow: View {
    let key: String
    let value: Any?
    let path: String
    @Binding var expandedKeys: Set<String>
    let searchText: String
    let onChange: (Any) -> Void
    let onDelete: () -> Void
    let onExplain: () -> Void
    
    @State private var isEditing = false
    @State private var editValue: String = ""
    @State private var showTypePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Disclosure indicator for complex types
                if isComplexType(value) {
                    Button(action: { toggleExpanded() }) {
                        Image(systemName: expandedKeys.contains(path) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.secondaryText)
                            .frame(width: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer().frame(width: 20)
                }
                
                // Key
                Text(key)
                    .font(AppFont.body.monospaced())
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                // Type badge
                Text(typeDisplayName)
                    .font(AppFont.caption2)
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(typeColor.opacity(0.15))
                    )
                
                // Value preview (for simple types)
                if !isComplexType(value) {
                    Text(valuePreview)
                        .font(AppFont.body.monospaced())
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
                
                // Edit button
                if !isComplexType(value) {
                    Button(action: { startEditing() }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.destructive.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.surface)
            )
            .contextMenu {
                Button {
                    onExplain()
                } label: {
                    Label("Explain with Assistant", systemImage: "brain")
                }
            }
            
            // Expanded children
            if isComplexType(value), expandedKeys.contains(path) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(childKeys, id: \.self) { childKey in
                        SimplePlistKeyRow(
                            key: childKey,
                            value: childValue(for: childKey),
                            path: "\(path).\(childKey)",
                            expandedKeys: $expandedKeys,
                            searchText: searchText,
                            onChange: { newValue in
                                if let parentDict = value as? [String: Any] {
                                    var mutableDict = parentDict
                                    mutableDict[childKey] = newValue
                                    onChange(mutableDict)
                                } else if let parentArray = value as? [Any],
                                          let index = Int(childKey.replacingOccurrences(of: "Item ", with: "")) {
                                    var mutableArray = parentArray
                                    if index < mutableArray.count {
                                        mutableArray[index] = newValue
                                        onChange(mutableArray)
                                    }
                                }
                            },
                            onDelete: {
                                if var parentDict = value as? [String: Any] {
                                    parentDict.removeValue(forKey: childKey)
                                    onChange(parentDict)
                                } else if let parentArray = value as? [Any],
                                          let index = Int(childKey.replacingOccurrences(of: "Item ", with: "")) {
                                    var mutableArray = parentArray
                                    if index < mutableArray.count {
                                        mutableArray.remove(at: index)
                                        onChange(mutableArray)
                                    }
                                }
                            },
                            onExplain: {
                                onExplain()
                            }
                        )
                        .padding(.leading, 24)
                    }
                    
                    // Add child button
                    Button(action: { addChild() }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                            Text("Add Item")
                                .font(AppFont.caption)
                        }
                        .foregroundColor(ThemeManager.shared.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 24)
                }
            }
        }
    }
    
    private var isExpanded: Bool {
        expandedKeys.contains(path)
    }
    
    private func toggleExpanded() {
        if isExpanded {
            expandedKeys.remove(path)
        } else {
            expandedKeys.insert(path)
        }
    }
    
    private var isDictionary: Bool {
        value is [String: Any]
    }
    
    private var isArray: Bool {
        value is [Any]
    }
    
    private func isComplexType(_ value: Any?) -> Bool {
        value is [String: Any] || value is [Any]
    }
    
    private var typeDisplayName: String {
        if value == nil { return "Null" }
        if let _ = value as? String { return "String" }
        if let _ = value as? Bool { return "Boolean" }
        if let _ = value as? Int { return "Integer" }
        if let _ = value as? Double { return "Real" }
        if let _ = value as? Date { return "Date" }
        if let _ = value as? Data { return "Data" }
        if isDictionary { return "Dictionary" }
        if isArray { return "Array" }
        return "Unknown"
    }
    
    private var typeColor: Color {
        switch typeDisplayName {
        case "String": return AppColors.success
        case "Boolean": return AppColors.info
        case "Integer", "Real": return AppColors.warning
        case "Date": return AppColors.accent
        case "Data": return AppColors.secondaryText
        case "Dictionary": return ThemeManager.shared.accentColor
        case "Array": return AppColors.warning
        default: return AppColors.disabledText
        }
    }
    
    private var valuePreview: String {
        guard let value = value else { return "null" }
        
        if let str = value as? String {
            return "\"\(str.prefix(50))\""
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let int = value as? Int {
            return "\(int)"
        } else if let double = value as? Double {
            return "\(double)"
        } else if let date = value as? Date {
            return date.formatted()
        } else if let data = value as? Data {
            return "<Data: \(data.count) bytes>"
        } else if let dict = value as? [String: Any] {
            return "{\(dict.count) keys}"
        } else if let array = value as? [Any] {
            return "[\(array.count) items]"
        }
        return "\(value)"
    }
    
    private var childKeys: [String] {
        if let dict = value as? [String: Any] {
            return Array(dict.keys).sorted()
        } else if let array = value as? [Any] {
            return array.indices.map { "Item \($0)" }
        }
        return []
    }
    
    private func childValue(for key: String) -> Any? {
        if let dict = value as? [String: Any] {
            return dict[key]
        } else if let array = value as? [Any],
                  let index = Int(key.replacingOccurrences(of: "Item ", with: "")),
                  index < array.count {
            return array[index]
        }
        return nil
    }
    
    private func startEditing() {
        editValue = valuePreview.replacingOccurrences(of: "\"", with: "")
        isEditing = true
    }
    
    private func addChild() {
        var newKey = "NewItem"
        var counter = 1
        
        if let dict = value as? [String: Any] {
            while dict["\(newKey)\(counter == 1 ? "" : "\(counter)")"] != nil {
                counter += 1
            }
            let finalKey = counter == 1 ? newKey : "\(newKey)\(counter)"
            var newDict = dict
            newDict[finalKey] = ""
            onChange(newDict)
            expandedKeys.insert("\(path).\(finalKey)")
        } else if var array = value as? [Any] {
            array.append("")
            onChange(array)
            expandedKeys.insert("\(path).Item \(array.count - 1)")
        }
    }
}