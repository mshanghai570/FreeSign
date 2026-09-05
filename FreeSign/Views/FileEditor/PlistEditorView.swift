import SwiftUI

// MARK: - PlistEditorView

/// Entry point for the plist editor.
/// Initialiser matches BundleBrowserView's existing call site.
struct PlistEditorView: View {
    @Environment(\.dismiss) var dismiss

    let plistPath: String
    let bundleName: String

    @StateObject private var doc: PlistDocument
    @State private var loadError: String?

    init(plistPath: String, bundleName: String) {
        self.plistPath = plistPath
        self.bundleName = bundleName
        if let d = try? PlistDocument(plistPath: plistPath) {
            _doc = StateObject(wrappedValue: d)
        } else {
            _doc = StateObject(wrappedValue: PlistDocument())
            // Error surfaced via .onAppear below
        }
    }

    var body: some View {
        NavigationStack {
            if let err = loadError {
                // ── Load failure ─────────────────────────────────────────────
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Cannot Open Plist",
                    message: err
                )
                .background(AppColors.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            } else {
                // ── Root level view ───────────────────────────────────────────
                PlistLevelView(
                    doc: doc,
                    containerID: nil,
                    title: (plistPath as NSString).lastPathComponent,
                    isArray: doc.isArrayRoot,
                    onDismiss: { dismiss() }
                )
            }
        }
        .onAppear {
            if doc.plistPath.isEmpty {
                loadError = PlistDocumentError.loadFailed.errorDescription
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - PlistLevelView

/// Shows the children at one level of the plist tree (root or any container).
/// Pushes itself recursively via NavigationLink for nested containers.
struct PlistLevelView: View {
    @ObservedObject var doc: PlistDocument
    let containerID: UUID?    // nil = root level
    let title: String
    let isArray: Bool
    var onDismiss: (() -> Void)? = nil

    @State private var showAddItem   = false
    @State private var showRawEditor = false
    @State private var searchText    = ""

    // Resolved list of nodes for this level
    private var nodes: [PlistNode] {
        if let cid = containerID {
            return doc.children(ofNodeID: cid)
        }
        return doc.rootNodes
    }

    private var filteredNodes: [PlistNode] {
        guard !searchText.isEmpty else { return nodes }
        return nodes.filter {
            ($0.key ?? "").localizedCaseInsensitiveContains(searchText) ||
            $0.value.valuePreview.localizedCaseInsensitiveContains(searchText) ||
            $0.value.typeName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                ForEach(filteredNodes) { node in
                    PlistRowView(doc: doc, node: node)
                        .listRowBackground(AppColors.surface)
                        .listRowSeparatorTint(AppColors.separator)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .onDelete { idxSet in
                    idxSet.map { filteredNodes[$0].id }.forEach { doc.deleteNode(id: $0) }
                }
                .onMove { source, dest in
                    doc.moveNodes(source: source, destination: dest, inContainerID: containerID)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search keys…")
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ── Title ──────────────────────────────────────────────────────
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(title)
                        .font(AppFont.headline)
                        .foregroundColor(AppColors.primaryText)
                    Text(countLabel)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
            }

            // ── Leading (Done at root, implicit Back when nested) ──────────
            if let onDismiss {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .font(AppFont.body)
                        .foregroundColor(AppColors.secondaryText)
                }
            }

            // ── Trailing actions ───────────────────────────────────────────
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddItem = true
                    } label: {
                        Label(isArray ? "Add Item" : "Add Key", systemImage: "plus")
                    }

                    if containerID == nil {
                        Button {
                            showRawEditor = true
                        } label: {
                            Label("Raw XML Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        // ── Sheets ──────────────────────────────────────────────────────────
        .sheet(isPresented: $showAddItem) {
            AddPlistItemView(isArray: isArray) { key, value in
                let node = PlistNode(key: key, value: value)
                doc.addNode(node, toContainerID: containerID)
            }
        }
        .sheet(isPresented: $showRawEditor) {
            RawPlistEditorView(rawText: .constant(doc.rawXML())) { xml in
                if containerID == nil { doc.applyRawXML(xml) }
            }
        }
    }

    private var countLabel: String {
        let n = nodes.count
        return isArray
            ? "\(n) item\(n == 1 ? "" : "s")"
            : "\(n) key\(n == 1 ? "" : "s")"
    }
}

// MARK: - PlistRowView

/// One row in the plist tree.
/// - Containers  → NavigationLink that pushes PlistLevelView
/// - Booleans    → Inline Toggle (no sheet navigation)
/// - Scalars     → Tap to open PlistValueEditorSheet
struct PlistRowView: View {
    @ObservedObject var doc: PlistDocument
    let node: PlistNode

    @State private var showEditor = false

    var body: some View {
        Group {
            switch node.value {
            case .boolean(let current):
                boolRow(current: current)
            case .dictionary, .array:
                containerRow
            default:
                scalarRow
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = node.key ?? node.value.valuePreview
            } label: { Label("Copy Key", systemImage: "doc.on.doc") }

            Button {
                UIPasteboard.general.string = node.value.valuePreview
            } label: { Label("Copy Value", systemImage: "doc.on.clipboard") }

            Divider()

            Button(role: .destructive) {
                withAnimation { doc.deleteNode(id: node.id) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Bool Row (inline toggle)

    private func boolRow(current: Bool) -> some View {
        HStack(spacing: 12) {
            PlistTypeBadge(value: node.value)
            keyLabel
            Spacer()
            Toggle("", isOn: Binding(
                get: {
                    if case .boolean(let b) = node.value { return b }
                    return false
                },
                set: { doc.updateValue(.boolean($0), forNodeID: node.id) }
            ))
            .tint(AppColors.accent)
            .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Container Row (dict / array)

    private var containerRow: some View {
        let isArr: Bool
        if case .array = node.value { isArr = true } else { isArr = false }

        return NavigationLink(destination:
            PlistLevelView(
                doc: doc,
                containerID: node.id,
                title: node.key ?? (isArr ? "Array" : "Dictionary"),
                isArray: isArr
            )
        ) {
            HStack(spacing: 12) {
                PlistTypeBadge(value: node.value)
                VStack(alignment: .leading, spacing: 3) {
                    keyLabel
                    Text(node.value.valuePreview)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.disabledText)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Scalar Row

    private var scalarRow: some View {
        Button {
            showEditor = true
        } label: {
            HStack(spacing: 12) {
                PlistTypeBadge(value: node.value)
                keyLabel
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(node.value.valuePreview)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .trailing)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showEditor) {
            PlistValueEditorSheet(doc: doc, node: node)
        }
    }

    // MARK: - Key label

    private var keyLabel: some View {
        Text(node.key ?? "(item)")
            .font(AppFont.body)
            .foregroundColor(AppColors.primaryText)
            .lineLimit(1)
    }
}

// MARK: - PlistTypeBadge

/// The colored capsule chip showing the type abbreviation.
struct PlistTypeBadge: View {
    let value: PlistNodeValue

    var body: some View {
        Text(value.typeShort)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(value.typeColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(value.typeColor.opacity(0.14))
            .clipShape(Capsule())
            .frame(minWidth: 40)
    }
}

// MARK: - PlistValueEditorSheet

/// Full-screen editor sheet for scalar plist values.
struct PlistValueEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var doc: PlistDocument
    let node: PlistNode

    @State private var editKey:    String = ""
    @State private var editString: String = ""
    @State private var editInt:    String = ""
    @State private var editReal:   String = ""
    @State private var editBool:   Bool   = false
    @State private var editDate:   Date   = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Header ─────────────────────────────────────────────
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(node.value.typeColor.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Text(node.value.typeShort)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(node.value.typeColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(node.key ?? "(array item)")
                                .font(AppFont.headline)
                                .foregroundColor(AppColors.primaryText)
                            Text(node.value.typeName)
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                    }
                    .appCard()
                    .padding(.horizontal, 16)

                    // ── Key name editor (dict keys only) ──────────────────
                    if node.key != nil {
                        labeledField("Key") {
                            TextField("Key name", text: $editKey)
                                .font(AppFont.mono)
                                .foregroundColor(AppColors.primaryText)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                    }

                    // ── Value editor ──────────────────────────────────────
                    Group {
                        switch node.value {
                        case .string:
                            labeledField("Value") {
                                TextField("String value", text: $editString, axis: .vertical)
                                    .font(AppFont.body)
                                    .foregroundColor(AppColors.primaryText)
                                    .lineLimit(1...6)
                                    .autocorrectionDisabled()
                                    .autocapitalization(.none)
                            }
                        case .integer:
                            labeledField("Value") {
                                TextField("0", text: $editInt)
                                    .font(AppFont.mono)
                                    .foregroundColor(AppColors.primaryText)
                                    .keyboardType(.numberPad)
                            }
                        case .real:
                            labeledField("Value") {
                                TextField("0.0", text: $editReal)
                                    .font(AppFont.mono)
                                    .foregroundColor(AppColors.primaryText)
                                    .keyboardType(.decimalPad)
                            }
                        case .boolean:
                            HStack {
                                Text("Value")
                                    .font(AppFont.body)
                                    .foregroundColor(AppColors.primaryText)
                                Spacer()
                                Toggle("", isOn: $editBool)
                                    .tint(AppColors.accent)
                                    .labelsHidden()
                            }
                            .padding(14)
                            .background(AppColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
                            .padding(.horizontal, 16)
                        case .date:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Value")
                                    .font(AppFont.caption)
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding(.horizontal, 4)
                                DatePicker("", selection: $editDate)
                                    .datePickerStyle(.graphical)
                                    .tint(AppColors.accent)
                                    .padding(14)
                                    .background(AppColors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
                            }
                            .padding(.horizontal, 16)
                        case .data:
                            labeledField("Value (hex)") {
                                TextField("Hex bytes", text: $editString)
                                    .font(AppFont.mono)
                                    .foregroundColor(AppColors.primaryText)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                            .opacity(0.6)   // data editing is display-only for now
                        default:
                            EmptyView()
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(AppFont.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commitEdit(); dismiss() }
                        .font(AppFont.button)
                        .foregroundColor(AppColors.accent)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(AppFont.body.bold())
                    .foregroundColor(AppColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { loadCurrentValues() }
    }

    // MARK: - Field helper

    @ViewBuilder
    private func labeledField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 4)
            content()
                .padding(14)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Load / Commit

    private func loadCurrentValues() {
        editKey = node.key ?? ""
        switch node.value {
        case .string(let s):  editString = s
        case .integer(let i): editInt    = "\(i)"
        case .real(let r):    editReal   = String(format: "%g", r)
        case .boolean(let b): editBool   = b
        case .date(let d):    editDate   = d
        case .data(let d):    editString = d.map { String(format: "%02x", $0) }.joined(separator: " ")
        default: break
        }
    }

    private func commitEdit() {
        // Update key if it changed
        if let oldKey = node.key, oldKey != editKey, !editKey.isEmpty {
            doc.updateKey(editKey, forNodeID: node.id)
        }
        // Update value
        switch node.value {
        case .string:
            doc.updateValue(.string(editString), forNodeID: node.id)
        case .integer:
            doc.updateValue(.integer(Int(editInt) ?? 0), forNodeID: node.id)
        case .real:
            doc.updateValue(.real(Double(editReal) ?? 0), forNodeID: node.id)
        case .boolean:
            doc.updateValue(.boolean(editBool), forNodeID: node.id)
        case .date:
            doc.updateValue(.date(editDate), forNodeID: node.id)
        default:
            break  // data editing not yet implemented
        }
    }
}

// MARK: - AddPlistItemView

/// Sheet that creates a new key-value pair at the current plist level.
struct AddPlistItemView: View {
    @Environment(\.dismiss) var dismiss

    let isArray: Bool
    let onAdd: (String?, PlistNodeValue) -> Void

    @State private var keyName     = ""
    @State private var selectedType: PlistItemType = .string
    @State private var stringVal   = ""
    @State private var intVal      = ""
    @State private var realVal     = ""
    @State private var boolVal     = false
    @State private var dateVal     = Date()

    enum PlistItemType: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case string      = "String"
        case integer     = "Integer"
        case real        = "Real"
        case boolean     = "Boolean"
        case date        = "Date"
        case array       = "Array"
        case dictionary  = "Dictionary"

        var color: Color {
            switch self {
            case .string:     return Color(hex: "#4A90D9")
            case .integer:    return Color(hex: "#E67E22")
            case .real:       return Color(hex: "#E67E22")
            case .boolean:    return Color(hex: "#27AE60")
            case .date:       return Color(hex: "#9B59B6")
            case .array:      return Color(hex: "#B87333")
            case .dictionary: return Color(hex: "#C9A84C")
            }
        }

        var icon: String {
            switch self {
            case .string:     return "text.quote"
            case .integer:    return "number"
            case .real:       return "plusminus"
            case .boolean:    return "switch.2"
            case .date:       return "calendar"
            case .array:      return "list.bullet"
            case .dictionary: return "rectangle.3.group"
            }
        }

        func toPlistNodeValue(
            string: String, int: String, real: String,
            bool: Bool, date: Date
        ) -> PlistNodeValue {
            switch self {
            case .string:     return .string(string)
            case .integer:    return .integer(Int(int) ?? 0)
            case .real:       return .real(Double(real) ?? 0)
            case .boolean:    return .boolean(bool)
            case .date:       return .date(date)
            case .array:      return .array([])
            case .dictionary: return .dictionary([])
            }
        }
    }

    var canAdd: Bool {
        isArray || !keyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Type picker ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 10) {
                            ForEach(PlistItemType.allCases) { type in
                                TypePickerCell(
                                    type: type,
                                    isSelected: selectedType == type,
                                    onTap: { selectedType = type }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // ── Key name (dict only) ──────────────────────────────
                    if !isArray {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Key Name")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(.horizontal, 4)
                            TextField("e.g. CFBundleIdentifier", text: $keyName)
                                .font(AppFont.mono)
                                .foregroundColor(AppColors.primaryText)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(AppColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Value input (type-specific) ───────────────────────
                    if selectedType != .array && selectedType != .dictionary {
                        valueInput
                            .padding(.horizontal, 16)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: selectedType == .array ? "list.bullet" : "rectangle.3.group")
                                .foregroundColor(selectedType.color)
                            Text("An empty \(selectedType.rawValue) will be created.\nYou can add items after.")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isArray ? "Add Item" : "Add Key")
                        .font(AppFont.headline)
                        .foregroundColor(AppColors.primaryText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(AppFont.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let value = selectedType.toPlistNodeValue(
                            string: stringVal, int: intVal, real: realVal,
                            bool: boolVal, date: dateVal
                        )
                        let key = isArray ? nil : keyName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onAdd(key.flatMap { $0.isEmpty ? nil : $0 }, value)
                        dismiss()
                    }
                    .font(AppFont.button)
                    .foregroundColor(canAdd ? AppColors.accent : AppColors.disabledText)
                    .disabled(!canAdd)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(AppFont.body.bold())
                    .foregroundColor(AppColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var valueInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Value")
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 4)

            switch selectedType {
            case .string:
                TextField("String value", text: $stringVal)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .padding(14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))

            case .integer:
                TextField("0", text: $intVal)
                    .font(AppFont.mono)
                    .foregroundColor(AppColors.primaryText)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))

            case .real:
                TextField("0.0", text: $realVal)
                    .font(AppFont.mono)
                    .foregroundColor(AppColors.primaryText)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))

            case .boolean:
                HStack {
                    Text(boolVal ? "true" : "false")
                        .font(AppFont.mono)
                        .foregroundColor(boolVal ? AppColors.success : AppColors.destructive)
                    Spacer()
                    Toggle("", isOn: $boolVal)
                        .tint(AppColors.accent)
                        .labelsHidden()
                }
                .padding(14)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))

            case .date:
                DatePicker("", selection: $dateVal)
                    .datePickerStyle(.compact)
                    .tint(AppColors.accent)
                    .padding(14)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))

            default:
                EmptyView()
            }
        }
    }
}

// MARK: - TypePickerCell

private struct TypePickerCell: View {
    let type: AddPlistItemView.PlistItemType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : type.color)
                Text(type.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? type.color : type.color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.color : type.color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    PlistEditorView(plistPath: "/dev/null", bundleName: "ExampleApp")
}
