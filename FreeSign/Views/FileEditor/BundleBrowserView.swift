import SwiftUI
import QuickLook

struct BundleBrowserView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var editor = BundleEditor.shared
    @State private var files: [FileEntry] = []
    @State private var currentPath: String
    @State private var showFilePreview = false
    @State private var previewURL: URL?
    @State private var showReplaceIconPicker = false
    @State private var showEditPlist = false
    @State private var selectedPlistPath: String?
    @State private var animateContent = false
    
    let extracted: BundleEditor.ExtractedApp
    
    init(extracted: BundleEditor.ExtractedApp) {
        self.extracted = extracted
        self._currentPath = State(initialValue: extracted.appFolderPath)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Bundle header
                bundleHeader
                
                // Quick actions
                quickActions
                
                // Bundle contents
                bundleContents
            }
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .appNavigationTitle("Bundle Editor")
        .appNavigationStyle()
        .onAppear {
            loadFiles()
            withAnimation(.easeOut(duration: 0.25)) { animateContent = true }
        }
        .sheet(isPresented: $showEditPlist) {
            PlistEditorView(
                plistPath: (currentPath as NSString).appendingPathComponent("Info.plist"),
                bundleName: extracted.appName
            )
        }
        .sheet(isPresented: $showReplaceIconPicker) {
            ImagePickerView { imageData in
                try? editor.replaceAppIcon(in: extracted.appFolderPath, with: imageData)
                loadFiles()
            }
        }
        .quickLookPreview($previewURL)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { dismiss() }
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
    
    // MARK: - Bundle Header
    
    private var bundleHeader: some View {
        HStack(spacing: 16) {
            if let iconPath = extracted.iconPath, let img = UIImage(contentsOfFile: iconPath) {
                Image(uiImage: img)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .cornerRadius(14)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.surface)
                        .frame(width: 56, height: 56)
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.accent)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(extracted.appName)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                HStack(spacing: 6) {
                    Text(extracted.bundleID)
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                    Text("v\(extracted.version)")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
            }
            
            Spacer()
        }
        .appCard()
        .padding(.horizontal, 16)
        .offset(y: animateContent ? 0 : 15)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.05), value: animateContent)
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                ActionButton(
                    icon: "doc.text",
                    title: "Info.plist",
                    subtitle: "Edit",
                    color: AppColors.accent,
                    action: { showEditPlist = true }
                )
                
                ActionButton(
                    icon: "photo",
                    title: "App Icon",
                    subtitle: "Replace",
                    color: AppColors.secondaryText,
                    action: { showReplaceIconPicker = true }
                )
                
                ActionButton(
                    icon: "folder",
                    title: "Reveal",
                    subtitle: "Copy Path",
                    color: AppColors.secondaryText,
                    action: { UIPasteboard.general.string = extracted.extractPath }
                )
            }
            .padding(.horizontal, 16)
        }
        .offset(y: animateContent ? 0 : 15)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.1), value: animateContent)
    }
    
    // MARK: - Bundle Contents
    
    private var bundleContents: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bundle Contents")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 20)
            
            if files.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(AppColors.accent)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 1) {
                    ForEach(files) { file in
                        FileRowView(file: file, basePath: currentPath) {
                            if file.isDirectory {
                                navigateTo(subpath: file.relativePath)
                            } else {
                                previewFile(file)
                            }
                        }
                    }
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
        }
        .offset(y: animateContent ? 0 : 15)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.25).delay(0.15), value: animateContent)
    }
    
    // MARK: - Helpers
    
    private func loadFiles() {
        files = (try? editor.listFiles(in: currentPath)) ?? []
    }
    
    private func navigateTo(subpath: String) {
        currentPath = (currentPath as NSString).appendingPathComponent(subpath)
        loadFiles()
    }
    
    private func previewFile(_ file: FileEntry) {
        let fullPath = (currentPath as NSString).appendingPathComponent(file.relativePath)
        previewURL = URL(fileURLWithPath: fullPath)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitle)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.easeOut(duration: 0.1), value: isPressed)
    }
}

// MARK: - File Row View

struct FileRowView: View {
    let file: FileEntry
    let basePath: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(file.isDirectory ? AppColors.accent.opacity(0.1) : AppColors.secondaryText.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: file.isDirectory ? "folder" : fileIcon)
                        .font(.system(size: 14))
                        .foregroundColor(file.isDirectory ? AppColors.accent : AppColors.secondaryText)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(file.fileName)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                    if !file.isDirectory {
                        Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                if file.isTextEditable || file.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.disabledText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
    }
    
    private var fileIcon: String {
        switch file.fileExtension {
        case "plist": return "list.bullet.rectangle"
        case "png", "jpg", "jpeg": return "photo"
        case "dylib": return "gearshape.2"
        case "framework": return "cube.box"
        case "app": return "app.fill"
        default: return "doc"
        }
    }
}

// MARK: - Preview

struct BundleBrowserPreview: View {
    let extracted = BundleEditor.ExtractedApp(
        sourceIPA: "/dev/null",
        extractPath: "/dev/null",
        appFolderPath: "/dev/null",
        bundleID: "com.example.app",
        appName: "ExampleApp",
        version: "1.0",
        minOS: "15.0",
        iconPath: nil
    )
    
    var body: some View {
        BundleBrowserView(extracted: extracted)
    }
}

#Preview {
    BundleBrowserPreview()
}
