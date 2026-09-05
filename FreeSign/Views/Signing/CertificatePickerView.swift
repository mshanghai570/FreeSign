import SwiftUI

// MARK: - Certificate Picker View

/// A sheet-based picker for selecting a signing certificate,
/// mirroring Feather's CertificatePickerView.
struct CertificatePickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var dataManager = AppDataManager.shared
    @Binding var selectedIndex: Int

    var body: some View {
        NavigationStack {
            List {
                if dataManager.certificates.isEmpty {
                    Text("No certificates available. Add one from the Certificates tab.")
                        .font(AppFont.body)
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(dataManager.certificates.enumerated()), id: \.offset) { index, cert in
                        Button {
                            selectedIndex = index
                            UserDefaults.standard.set(index, forKey: "feather.selectedCert")
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(cert.name)
                                        .font(AppFont.body)
                                        .foregroundColor(AppColors.primaryText)

                                    if cert.isExpired {
                                        Text("Expired")
                                            .font(AppFont.caption)
                                            .foregroundColor(AppColors.destructive)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppColors.destructive.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(cert.teamID)
                                    .font(AppFont.small)
                                    .foregroundColor(AppColors.secondaryText)

                                Text("Expires \(cert.expirationDate, style: .date)")
                                    .font(AppFont.small)
                                    .foregroundColor(AppColors.disabledText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(
                            index == selectedIndex ? AppColors.surfaceHover : AppColors.surface
                        )
                    }
                    .onDelete(perform: delete)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .listRowBackground(AppColors.surface)
            .navigationTitle("Select Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let certsToRemove = offsets.map { dataManager.certificates[$0] }
        for cert in certsToRemove {
            dataManager.removeCertificate(cert)
        }
    }
}

#Preview {
    CertificatePickerView(selectedIndex: .constant(0))
}
