import SwiftUI
import QuickLook

// MARK: - FileRow

struct FileRow: View {
    let file: FileItem
    let isSelected: Bool
    @ObservedObject var viewModel: FilesViewModel
    @Binding var plistFileURL: URL?
    @Binding var hexEditorFileURL: URL?
    @Binding var textEditorFileURL: URL?
    @Binding var quickLookFileURL: URL?
    @Binding var localModelInfoFileURL: URL?
    @Binding var moveFileItem: FileItem?
    @Binding var navigateToDirectory: URL?
    @Binding var showExtractProgress: Bool
    @Binding var extractProgress: Double
    @Binding var extractFileName: String
    
    let onExtractArchive: (FileItem) -> Void
    let onPackageApp: (FileItem) -> Void
    let onImportIPA: (FileItem) -> Void
    let onImportCertificate: (FileItem) -> Void
    let onImportProvisioningProfile: (FileItem) -> Void
    let onOpenInEditor: (FileItem) -> Void
    
    var body: some View {
        Button(action: {
            handleTap()
        }) {
            HStack(spacing: 14) {
                // File Icon
                fileIconView
                    .frame(width: 44, height: 44)
                
                // File Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(AppFont.headline)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if !file.isDirectory {
                            Text(file.formattedSize)
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        if let date = file.creationDate {
                            if !file.isDirectory {
                                Text("·")
                                    .font(AppFont.caption)
                                    .foregroundColor(AppColors.disabledText)
                            }
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    
                    // File type badge
                    Text(file.fileTypeDisplayName)
                        .font(AppFont.small)
                        .fontWeight(.semibold)
                        .foregroundColor(file.fileIconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(file.fileIconColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Selection/Navigation indicator
                if viewModel.isEditMode == .inactive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.disabledText)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? ThemeManager.shared.accentColor : AppColors.disabledText)
                }
            }
            .padding(14)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuButtons()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            swipeActionButtons()
        }
    }
    
    // MARK: - File Icon View
    
    @ViewBuilder
    private var fileIconView: some View {
        if file.isImageFile, let image = UIImage(contentsOfFile: file.url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(file.fileIconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: file.fileIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(file.fileIconColor)
            }
        }
    }
    
    // MARK: - Tap Handling
    
    private func handleTap() {
        if viewModel.isEditMode == .active {
            viewModel.toggleSelection(for: file)
        } else if file.isDirectory {
            navigateToDirectory = file.url
        } else {
            openFile(in: file)
        }
    }
    
    private func openFile(in file: FileItem) {
        if file.isP12Certificate {
            onImportCertificate(file)
        } else if file.isMobileProvision {
            onImportProvisioningProfile(file)
        } else if file.isPlistFile || file.isEntitlementsFile {
            plistFileURL = file.url
        } else if file.isTextFile || file.isCodeFile {
            textEditorFileURL = file.url
        } else if file.isImageFile {
            quickLookFileURL = file.url
        } else if file.isLocalModelFile {
            // Model weights are opaque binaries — there is nothing to preview.
            // Show metadata + how to use it with the Local Model provider instead.
            localModelInfoFileURL = file.url
        } else {
            // Default: try Quick Look preview
            quickLookFileURL = file.url
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuButtons() -> some View {
        // Preview
        if !file.isDirectory && !file.isLocalModelFile {
            Button {
                quickLookFileURL = file.url
            } label: {
                Label("Preview", systemImage: "eye")
            }
        }

        // Model Info
        if file.isLocalModelFile {
            Button {
                localModelInfoFileURL = file.url
            } label: {
                Label("Model Info", systemImage: "cpu")
            }
        }
        
        // Text Editor
        if file.isTextFile || file.isCodeFile {
            Button {
                textEditorFileURL = file.url
            } label: {
                Label("Text Editor", systemImage: "doc.plaintext")
            }
        }
        
        // Plist Editor
        if file.isPlistFile || file.isEntitlementsFile {
            Button {
                plistFileURL = file.url
            } label: {
                Label("Plist Editor", systemImage: "list.bullet.rectangle")
            }
        }
        
        // Hex Editor
        if !file.isDirectory && !file.isLocalModelFile {
            Button {
                hexEditorFileURL = file.url
            } label: {
                Label("Hex Editor", systemImage: "doc.text")
            }
        }
        
        // Certificate Import
        if file.isP12Certificate {
            Button {
                onImportCertificate(file)
            } label: {
                Label("Import Certificate", systemImage: "key.fill")
            }
        }

        // Provisioning profile import
        if file.isMobileProvision {
            Button {
                onImportProvisioningProfile(file)
            } label: {
                Label("Import Provisioning Profile", systemImage: "doc.text.badge.plus")
            }
        }
        
        // IPA Import to Library
        if file.isIPA {
            Button {
                onImportIPA(file)
            } label: {
                Label("Import to Library", systemImage: "square.grid.2x2")
            }
        }
        
        // Package App as IPA
        if file.isAppDirectory {
            Button {
                onPackageApp(file)
            } label: {
                Label("Package as IPA", systemImage: "doc.zipper")
            }
        }
        
        // Extract Archive
        if file.isArchive {
            Button {
                onExtractArchive(file)
            } label: {
                Label("Extract", systemImage: "doc.zipper")
            }
        }
        
        Divider()
        
        // Move
        Button {
            moveFileItem = file
        } label: {
            Label("Move", systemImage: "folder")
        }
        
        // Rename
        Button {
            showRenameDialog()
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        // Share
        if !file.isDirectory {
            Button {
                shareFile()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        
        Divider()
        
        // Delete
        Button(role: .destructive) {
            viewModel.deleteFile(file)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    private func swipeActionButtons() -> some View {
        Button(role: .destructive) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.deleteFile(file)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        Button {
            showRenameDialog()
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        .tint(.blue)
    }
    
    // MARK: - Helper Actions
    
    private func showRenameDialog() {
        UIAlertController.showAlertWithTextBox(
            title: "Rename",
            message: "Enter a new name",
            textFieldPlaceholder: "File name",
            textFieldText: file.name,
            submit: "Rename",
            cancel: "Cancel",
            onSubmit: { name in
                viewModel.renameFile(newName: name, item: file)
            }
        )
    }
    
    private func shareFile() {
        let activityVC = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
