import SwiftUI

// MARK: - Configuration View (Signing Options)

/// Settings screen for managing persistent signing options,
/// mirroring Feather's ConfigurationView.
struct ConfigurationView: View {
    @StateObject private var optionsManager = OptionsManager.shared
    @State private var isRandomAlertPresenting = false
    @State private var randomString = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // PPQ String
                ppqStringSection

                // Dictionary Rules
                displayNamesSection

                identifiersSection

                // Full Signing Options
                SigningOptionsView(options: $optionsManager.options)
                    .offset(y: 1)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .appNavigationTitle("Signing Options")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isRandomAlertPresenting = true
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .alert("PPQ String", isPresented: $isRandomAlertPresenting, actions: randomMenuAlert)
        .onChange(of: optionsManager.options) { _ in
            optionsManager.saveOptions()
        }
    }

    // MARK: - PPQ String

    private var ppqStringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PPQ Protection String")

            VStack(spacing: 14) {
                // Current string
                HStack(spacing: 12) {
                    Text(optionsManager.options.ppqString)
                        .font(AppFont.mono)
                        .foregroundColor(AppColors.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        UIPasteboard.general.string = optionsManager.options.ppqString
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Change button
                Button("Change String") {
                    isRandomAlertPresenting = true
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .frame(height: 40)
            }
            .padding(16)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Display Names

    private var displayNamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Display Names")

            VStack(spacing: 0) {
                NavigationLink {
                    ConfigurationDictView(
                        title: "Display Names",
                        dataDict: $optionsManager.options.displayNames
                    )
                } label: {
                    HStack {
                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.secondaryText)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Display Names")
                                .font(AppFont.body)
                                .foregroundColor(AppColors.primaryText)
                            Text("\(optionsManager.options.displayNames.count) rule(s)")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                AppDivider(leadingPadding: 16)

                NavigationLink {
                    ConfigurationDictView(
                        title: "Identifiers",
                        dataDict: $optionsManager.options.identifiers
                    )
                } label: {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.secondaryText)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Identifiers")
                                .font(AppFont.body)
                                .foregroundColor(AppColors.primaryText)
                            Text("\(optionsManager.options.identifiers.count) rule(s)")
                                .font(AppFont.small)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Identifiers

    private var identifiersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Replacement Rules")

            Text("These rules automatically replace bundle IDs and display names when signing apps.")
                .font(AppFont.caption)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 4)

            Text("Display names and bundle IDs that match a rule will be replaced with the specified value. This is useful for resolving conflicts when installing apps from the same repository.")
                .font(AppFont.small)
                .foregroundColor(AppColors.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Random Menu Alert

    @ViewBuilder
    private func randomMenuAlert() -> some View {
        TextField("Enter a custom PPQ string", text: $randomString)
            .textInputAutocapitalization(.none)

        Button("Save") {
            if !randomString.isEmpty {
                optionsManager.options.ppqString = randomString
                randomString = ""
            }
        }

        Button("Cancel", role: .cancel) {
            randomString = ""
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack {
        ConfigurationView()
    }
}
