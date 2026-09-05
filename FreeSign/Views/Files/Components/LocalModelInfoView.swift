import SwiftUI

// MARK: - Local Model Info

/// Shown when a user taps a GGUF / MLX / safetensors file in the Files tab.
///
/// Model weight files are opaque binaries, so there is nothing meaningful to
/// preview, edit as text, or render in the hex editor (a multi-GB load would
/// also exhaust memory). This sheet surfaces the metadata that matters and
/// explains how to use the model with the Lab Assistant's Local Model provider.
struct LocalModelInfoView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var showCopied = false

    private var fileExtension: String {
        fileURL.pathExtension.uppercased()
    }

    private var fileSize: Int64 {
        StorageManager.shared.fileSize(at: fileURL.path)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppColors.info.opacity(0.15))
                                .frame(width: 72, height: 72)
                            Image(systemName: "cpu")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(AppColors.info)
                        }

                        Text(fileURL.lastPathComponent)
                            .font(AppFont.headline)
                            .foregroundColor(AppColors.primaryText)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)

                        HStack(spacing: 8) {
                            Text(fileExtension)
                                .font(AppFont.caption.bold())
                                .foregroundColor(AppColors.info)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.info.opacity(0.15))
                                .clipShape(Capsule())

                            Text(StorageManager.formattedSize(fileSize))
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(label: "File", value: fileURL.lastPathComponent)
                        detailRow(label: "Type", value: fileExtension)
                        detailRow(label: "Size", value: StorageManager.formattedSize(fileSize))
                        detailRow(label: "Location", value: fileURL.path)
                    }
                    .padding(16)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )

                    // How to use
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How to use this model", systemImage: "sparkles")
                            .font(AppFont.body.bold())
                            .foregroundColor(AppColors.primaryText)

                        Text("This is a local model weight file. FreeSign doesn't run inference on-device — it points the Lab Assistant at your own inference server (llama.cpp, Ollama, etc.).")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)

                        Text("1. Add the model in Settings → Lab Assistant → New Provider → Local Model.\n2. Set the endpoint to your local server.\n3. Pick this file in the \"Model File\" picker.")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(16)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )

                    // Actions
                    Button {
                        UIPasteboard.general.string = fileURL.path
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "Copied" : "Copy Path", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.info)
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Model Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(AppFont.caption)
                .foregroundColor(AppColors.primaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    LocalModelInfoView(fileURL: URL(fileURLWithPath: "/tmp/llama-3.2-1b-q4.gguf"))
}
