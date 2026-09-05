import SwiftUI

// MARK: - TextEditorView

struct TextEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var textContent: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasChanges = false
    @State private var fontSize: CGFloat = 14
    @State private var showFind = false
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var showReplace = false
    
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
                        Text("Failed to load file")
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
                    textEditorContent
                }
            }
            .appNavigationTitle(fileURL.lastPathComponent)
            .appNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showDiscardAlert()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFile()
                    }
                    .disabled(!hasChanges)
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button {
                            fontSize = max(8, fontSize - 1)
                        } label: {
                            Label("Decrease Font", systemImage: "textformat.size.smaller")
                        }
                        
                        Button {
                            fontSize = min(32, fontSize + 1)
                        } label: {
                            Label("Increase Font", systemImage: "textformat.size.larger")
                        }
                        
                        Divider()
                        
                        Button {
                            showFind = true
                        } label: {
                            Label("Find", systemImage: "magnifyingglass")
                        }
                        
                        Button {
                            showFind = true
                            showReplace = true
                        } label: {
                            Label("Find & Replace", systemImage: "arrow.left.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadFile()
            }
            .sheet(isPresented: $showFind) {
                FindReplaceView(
                    text: $textContent,
                    findText: $findText,
                    replaceText: $replaceText,
                    showReplace: $showReplace,
                    onDismiss: { showFind = false }
                )
                .presentationDetents([.medium])
            }
            .alert("Save Changes?", isPresented: $showSaveConfirmation) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Save") { saveFile(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Would you like to save them?")
            }
        }
    }
    
    @State private var showSaveConfirmation = false
    
    @ViewBuilder
    private var textEditorContent: some View {
        VStack(spacing: 0) {
            // Line numbers and text editor
            HStack(spacing: 0) {
                // Line numbers
                LineNumberView(text: textContent, fontSize: fontSize)
                    .frame(width: 50)
                    .background(AppColors.surface)
                
                Divider()
                    .background(AppColors.cardBorder)
                
                // Text editor
                TextEditor(text: Binding(
                    get: { textContent },
                    set: { newValue in
                        textContent = newValue
                        hasChanges = newValue != originalContent
                    }
                ))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(AppColors.primaryText)
                .background(ThemeManager.shared.backgroundView)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func loadFile() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                DispatchQueue.main.async {
                    self.textContent = content
                    self.originalContent = content
                    self.isLoading = false
                }
            } catch {
                // Try other encodings
                var loaded = false
                for encoding in [String.Encoding.isoLatin1, .windowsCP1252, .utf16, .utf32] {
                    if let content = try? String(contentsOf: fileURL, encoding: encoding) {
                        DispatchQueue.main.async {
                            self.textContent = content
                            self.originalContent = content
                            self.isLoading = false
                        }
                        loaded = true
                        break
                    }
                }
                
                if !loaded {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func saveFile() {
        do {
            try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
            hasChanges = false
            originalContent = textContent
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    private func showDiscardAlert() {
        showSaveConfirmation = true
    }
}

// MARK: - Line Number View

struct LineNumberView: View {
    let text: String
    let fontSize: CGFloat
    
    private var lines: [String] {
        text.components(separatedBy: .newlines)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(lines.count, 1), id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundColor(AppColors.disabledText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.vertical, 2)
                }
            }
            .padding(.top, 8)
        }
        .background(AppColors.surface)
    }
}

// MARK: - Find Replace View

struct FindReplaceView: View {
    @Binding var text: String
    @Binding var findText: String
    @Binding var replaceText: String
    @Binding var showReplace: Bool
    let onDismiss: () -> Void
    @State private var matchCount = 0
    @State private var currentMatch = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Find field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    HStack {
                        TextField("Search...", text: $findText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: findText) { _ in updateMatches() }
                        
                        if !findText.isEmpty {
                            Text("\(currentMatch) of \(matchCount)")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .frame(width: 80)
                            
                            HStack(spacing: 8) {
                                Button {
                                    findPrevious()
                                } label: {
                                    Image(systemName: "chevron.up")
                                }
                                .disabled(matchCount == 0)
                                
                                Button {
                                    findNext()
                                } label: {
                                    Image(systemName: "chevron.down")
                                }
                                .disabled(matchCount == 0)
                            }
                        }
                    }
                }
                
                // Replace field
                if showReplace {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replace")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        HStack {
                            TextField("Replace with...", text: $replaceText)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Replace") {
                                replaceCurrent()
                            }
                            .disabled(matchCount == 0)
                            
                            Button("Replace All") {
                                replaceAll()
                            }
                            .disabled(matchCount == 0)
                        }
                    }
                }
                
                // Options
                HStack {
                    Toggle("Case Sensitive", isOn: .constant(false))
                        .font(AppFont.caption)
                    
                    Toggle("Whole Words", isOn: .constant(false))
                        .font(AppFont.caption)
                    
                    Spacer()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Find & Replace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func updateMatches() {
        guard !findText.isEmpty else {
            matchCount = 0
            currentMatch = 0
            return
        }
        
        let components = text.components(separatedBy: findText)
        matchCount = components.count - 1
        currentMatch = matchCount > 0 ? 1 : 0
    }
    
    private func findNext() {
        guard currentMatch < matchCount else { return }
        currentMatch += 1
    }
    
    private func findPrevious() {
        guard currentMatch > 1 else { return }
        currentMatch -= 1
    }
    
    private func replaceCurrent() {
        guard matchCount > 0, !findText.isEmpty else { return }
        
        var components = text.components(separatedBy: findText)
        let before = components[0..<currentMatch].joined(separator: findText)
        let after = components[currentMatch...].joined(separator: findText)
        text = before + replaceText + (currentMatch < components.count - 1 ? findText : "") + after
        
        updateMatches()
    }
    
    private func replaceAll() {
        guard matchCount > 0, !findText.isEmpty else { return }
        text = text.replacingOccurrences(of: findText, with: replaceText)
        updateMatches()
    }
}