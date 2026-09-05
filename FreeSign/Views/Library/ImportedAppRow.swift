import SwiftUI

// MARK: - Imported App Row

struct ImportedAppRow: View {
    let app: AppInfo

    // Icon is loaded lazily from disk on first render
    @State private var iconImage: UIImage? = nil

    var body: some View {
        HStack(spacing: 14) {
            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.surface2)
                    .frame(width: 52, height: 52)
                if let img = iconImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.disabledText)
                }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(app.bundleID)
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    Text("·")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                    Text("v\(app.version)")
                        .font(AppFont.caption)
                        .foregroundColor(AppColors.disabledText)
                }
                HStack(spacing: 8) {
                    Text(app.formattedSize)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.disabledText)
                    if app.isEncrypted {
                        StatusBadge(text: "Encrypted", color: AppColors.warning)
                    }
                    if !app.architectures.isEmpty {
                        StatusBadge(text: app.architectureString, color: AppColors.accent)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.disabledText)
        }
        .padding(14)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
        .task {
            if iconImage == nil, let path = app.iconPath {
                iconImage = UIImage(contentsOfFile: path)
            }
        }
    }
}

#Preview {
    let previewApp = AppInfo(
        id: UUID(),
        name: "Test App",
        bundleID: "com.example.test",
        version: "1.0.0",
        buildNumber: "1",
        minOSVersion: "15.0",
        ipaPath: "/path/to/test.ipa",
        iconPath: nil,
        fileSize: 1024 * 1024,
        architectures: ["arm64"],
        embeddedFrameworks: [],
        isEncrypted: false,
        isSigned: false,
        isFavorite: false,
        tags: [],
        dateImported: Date(),
        sourceURL: nil
    )
    
    NavigationStack {
        ImportedAppRow(app: previewApp)
            .padding()
    }
}