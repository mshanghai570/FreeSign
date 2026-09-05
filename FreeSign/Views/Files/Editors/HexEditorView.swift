import SwiftUI

// MARK: - HexEditorView

struct HexEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var fileData: Data = Data()
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var bytesPerRow: Int = 16
    @State private var showFind = false
    @State private var findHex = ""
    @State private var goToOffset = ""
    @State private var selectedOffset: Int? = nil
    @State private var showGoTo = false
    
    private let bytesPerRowOptions = [8, 16, 32]
    
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
                    hexEditorContent
                }
            }
            .appNavigationTitle(fileURL.lastPathComponent)
            .appNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Picker("Bytes per Row", selection: $bytesPerRow) {
                            ForEach(bytesPerRowOptions, id: \.self) { count in
                                Text("\(count) bytes").tag(count)
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            showFind = true
                        } label: {
                            Label("Find", systemImage: "magnifyingglass")
                        }
                        
                        Button {
                            showGoTo = true
                        } label: {
                            Label("Go to Offset", systemImage: "arrow.right")
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
                HexFindView(
                    data: fileData,
                    findHex: $findHex,
                    onFind: { offset in
                        selectedOffset = offset
                        showFind = false
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showGoTo) {
                GoToOffsetView(
                    maxOffset: fileData.count - 1,
                    offset: $goToOffset,
                    onGo: { offset in
                        selectedOffset = offset
                        showGoTo = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
    
    @ViewBuilder
    private var hexEditorContent: some View {
        VStack(spacing: 0) {
            // Info bar
            HStack {
                Text("\(fileData.count) bytes")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                
                Spacer()
                
                Picker("Bytes/Row", selection: $bytesPerRow) {
                    ForEach(bytesPerRowOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppColors.surface)
            
            Divider()
                .background(AppColors.cardBorder)
            
            // Hex dump
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<rowCount, id: \.self) { rowIndex in
                            HexRow(
                                data: fileData,
                                rowIndex: rowIndex,
                                bytesPerRow: bytesPerRow,
                                selectedOffset: $selectedOffset
                            )
                            .id("row-\(rowIndex)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedOffset) { newOffset in
                    if let offset = newOffset {
                        let rowIndex = offset / bytesPerRow
                        withAnimation {
                            proxy.scrollTo("row-\(rowIndex)", anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private var rowCount: Int {
        (fileData.count + bytesPerRow - 1) / bytesPerRow
    }
    
    private func loadFile() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: fileURL)
                DispatchQueue.main.async {
                    self.fileData = data
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Hex Row

struct HexRow: View {
    let data: Data
    let rowIndex: Int
    let bytesPerRow: Int
    @Binding var selectedOffset: Int?
    
    private var offset: Int {
        rowIndex * bytesPerRow
    }
    
    private var rowData: Data {
        let end = min(offset + bytesPerRow, data.count)
        return data.subdata(in: offset..<end)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Offset column
            Text(String(format: "%08X", offset))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.disabledText)
                .frame(width: 80, alignment: .trailing)
                .padding(.trailing, 16)
            
            // Hex bytes
            HStack(spacing: 4) {
                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                    let absoluteOffset = offset + byteIndex
                    
                    if absoluteOffset < data.count {
                        let byte = data[absoluteOffset]
                        let isSelected = selectedOffset == absoluteOffset
                        
                        Text(String(format: "%02X", byte))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(isSelected ? .white : AppColors.primaryText)
                            .frame(width: 24, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isSelected ? ThemeManager.shared.accentColor : Color.clear)
                            )
                            .onTapGesture {
                                selectedOffset = absoluteOffset
                            }
                    } else {
                        Text("  ")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 24)
                    }
                    
                    if byteIndex == 7 {
                        Text(" ")
                            .frame(width: 8)
                    }
                }
            }
            .frame(minWidth: 24 * 16 + 8, alignment: .leading)
            
            // ASCII column
            Text("  ")
            
            HStack(spacing: 0) {
                ForEach(0..<bytesPerRow, id: \.self) { byteIndex in
                    let absoluteOffset = offset + byteIndex
                    
                    if absoluteOffset < data.count {
                        let byte = data[absoluteOffset]
                        let char = Character(UnicodeScalar(byte))
                        let printableChar = char.isASCII && !char.isWhitespace && char != "\n" && char != "\r" ? String(char) : "."
                        let isSelected = selectedOffset == absoluteOffset
                        
                        Text(printableChar)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                            .frame(width: 12, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isSelected ? ThemeManager.shared.accentColor : Color.clear)
                            )
                    } else {
                        Text(" ")
                            .frame(width: 12)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 1)
        .background(
            selectedOffset != nil && (offset...offset+bytesPerRow-1).contains(selectedOffset!) 
                ? ThemeManager.shared.accentColor.opacity(0.05) 
                : Color.clear
        )
    }
}

// MARK: - Hex Find View

struct HexFindView: View {
    let data: Data
    @Binding var findHex: String
    let onFind: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var matches: [Int] = []
    @State private var currentMatch = 0
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find Hex Pattern")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    HStack {
                        TextField("Enter hex bytes (e.g. 48 65 6C 6C 6F)", text: $findHex)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                search()
                            }
                        
                        Button("Search") {
                            search()
                        }
                        .disabled(findHex.isEmpty || isSearching)
                    }
                }
                
                if isSearching {
                    ProgressView("Searching...")
                } else if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Found \(matches.count) match\(matches.count == 1 ? "" : "es")")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        HStack {
                            Button("Previous") {
                                if currentMatch > 0 { currentMatch -= 1 }
                            }
                            .disabled(currentMatch == 0)
                            
                            Text("\(currentMatch + 1) of \(matches.count)")
                                .font(AppFont.caption)
                                .frame(width: 100)
                            
                            Button("Next") {
                                if currentMatch < matches.count - 1 { currentMatch += 1 }
                            }
                            .disabled(currentMatch >= matches.count - 1)
                        }
                        
                        Button("Go to Offset 0x\(String(format: "%X", matches[currentMatch]))") {
                            onFind(matches[currentMatch])
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if !findHex.isEmpty {
                    Text("No matches found")
                        .font(AppFont.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Find Hex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func search() {
        guard !findHex.isEmpty else { return }
        
        // Parse hex string
        let hexBytes = findHex
            .split(separator: " ")
            .compactMap { UInt8($0, radix: 16) }
        
        guard !hexBytes.isEmpty else { return }
        
        isSearching = true
        matches = []
        currentMatch = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [Int] = []
            
            if hexBytes.count == 1 {
                // Single byte search
                for i in 0..<data.count {
                    if data[i] == hexBytes[0] {
                        found.append(i)
                    }
                }
            } else {
                // Multi-byte search
                for i in 0..<(data.count - hexBytes.count + 1) {
                    var match = true
                    for j in 0..<hexBytes.count {
                        if data[i + j] != hexBytes[j] {
                            match = false
                            break
                        }
                    }
                    if match {
                        found.append(i)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.matches = found
                self.isSearching = false
            }
        }
    }
}

// MARK: - Go To Offset View

struct GoToOffsetView: View {
    let maxOffset: Int
    @Binding var offset: String
    let onGo: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Go to Offset")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    TextField("Enter offset (hex or decimal)", text: $offset)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .keyboardType(.numbersAndPunctuation)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.destructive)
                    }
                    
                    Text("Valid range: 0 - \(maxOffset) (0x\(String(format: "%X", maxOffset)))")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
                
                Button("Go") {
                    navigateToOffset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(offset.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Go to Offset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func navigateToOffset() {
        errorMessage = nil
        
        let parsedOffset: Int?
        if offset.hasPrefix("0x") || offset.hasPrefix("0X") {
            parsedOffset = Int(offset.dropFirst(2), radix: 16)
        } else {
            parsedOffset = Int(offset)
        }
        
        guard let targetOffset = parsedOffset else {
            errorMessage = "Invalid offset format"
            return
        }
        
        if targetOffset < 0 || targetOffset > maxOffset {
            errorMessage = "Offset out of range (0 - \(maxOffset))"
            return
        }
        
        onGo(targetOffset)
    }
}