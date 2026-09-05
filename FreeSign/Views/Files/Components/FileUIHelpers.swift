import SwiftUI

// MARK: - FileUIHelpers

struct FileUIHelpers {
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    static func swipeActions(for file: FileItem, viewModel: FilesViewModel) -> some View {
        Button(role: .destructive) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.deleteFile(file)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        Button {
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
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        .tint(.blue)
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    static func emptyStateView(for category: FileCategory, onImport: @escaping () -> Void) -> some View {
        EmptyStateView(
            icon: category.systemImage,
            title: "No \(category.rawValue)",
            message: emptyStateMessage(for: category),
            actionTitle: "Import Files",
            action: onImport
        )
    }
    
    private static func emptyStateMessage(for category: FileCategory) -> String {
        switch category {
        case .all:
            return "Get started by importing your first file. You can add IPAs, dylibs, certificates, provisioning profiles, and more."
        case .ipas:
            return "Import IPA files to manage and sign them."
        case .dylibs:
            return "Add dynamic libraries for injection during signing."
        case .certificates:
            return "Import .p12 certificates for code signing."
        case .profiles:
            return "Add .mobileprovision profiles for code signing."
        case .plists:
            return "Property lists and entitlements files will appear here."
        case .frameworks:
            return "Framework bundles will appear here."
        case .archives:
            return "ZIP, DEB, and other archives will appear here."
        case .models:
            return "GGUF and MLX model files for the Lab Assistant's local model provider will appear here."
        case .images:
            return "Image files will appear here."
        case .text:
            return "Text and code files will appear here."
        case .folders:
            return "Create folders to organize your files."
        case .other:
            return "Other file types will appear here."
        }
    }
    
    // MARK: - Category Filter Chips
    
    @ViewBuilder
    static func categoryFilterChips(
        selectedCategory: Binding<FileCategory>,
        fileCounts: [FileCategory: Int]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FileCategory.allCases) { category in
                    FilterChip(
                        category: category,
                        isSelected: selectedCategory.wrappedValue == category,
                        count: fileCounts[category] ?? 0,
                        action: { selectedCategory.wrappedValue = category }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let category: FileCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(category.rawValue)
                    .font(AppFont.caption)
                if count > 0 {
                    Text("\(count)")
                        .font(AppFont.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : ThemeManager.shared.accentColor.opacity(0.2))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : AppColors.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? ThemeManager.shared.accentColor : ThemeManager.shared.accentColor.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extraction Progress View

struct ExtractionProgressView: View {
    let fileName: String
    let progress: Double
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Extracting \(fileName)")
                .font(AppFont.headline)
                .foregroundColor(AppColors.primaryText)
            
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 280)
            
            Text("\(Int(progress * 100))%")
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
            
            Button("Cancel", action: onCancel)
                .font(AppFont.body)
                .foregroundColor(ThemeManager.shared.accentColor)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surface)
        )
        .shadow(radius: 20)
    }
}