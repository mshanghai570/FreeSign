import SwiftUI

// MARK: - Picker Option Protocol

/// Protocol for picker options to support heterogeneous types
protocol PickerOptionProtocol: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var value: any Hashable { get }
}

// MARK: - Picker Option

/// Generic picker option that conforms to PickerOptionProtocol
struct PickerOption: PickerOptionProtocol {
    let id: UUID
    let title: String
    let value: any Hashable
    
    /// Initialize with a Hashable value
    init<T: Hashable>(title: String, value: T) {
        self.id = UUID()
        self.title = title
        self.value = value
    }
}

// MARK: - Picker Option Extensions for Enums

extension ThemePreset: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

extension ThemeCardStyle: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

extension AppIconStyle: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

extension SigningBehavior: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

extension RepositoryBehavior: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

extension AppSorting: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

extension CertificateValidation: PickerOptionProtocol {
    var id: UUID { UUID() }
    var title: String { self.displayName }
    var value: any Hashable { self }
}

// MARK: - Toggle Row

/// Reusable toggle row for settings (with subtitle).
/// The whole row is the toggle's label so tapping anywhere on the row flips it.
struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)

                Text(subtitle)
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ThemeManager.shared.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Picker Row

/// Reusable picker row for settings (with subtitle).
/// The entire row is the menu picker's label, so tapping anywhere opens the menu.
struct PickerRow<T: Hashable>: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    @Binding var selection: T
    let options: [PickerOption]
    
    private var selectedTitle: String? {
        options.first { ($0.value as? T) == selection }?.title
    }
    
    var body: some View {
        Picker(selection: $selection) {
            ForEach(options) { option in
                if let value = option.value as? T {
                    Text(option.title).tag(value)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(subtitle)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                if let current = selectedTitle {
                    Text(current)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.disabledText)
            }
        }
        .pickerStyle(.menu)
        .tint(AppColors.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Reusable picker row for settings (without subtitle, used in SigningView).
/// The entire row is the menu picker's label, so tapping anywhere opens the menu.
struct SimplePickerRow: View {
    let icon: String
    let title: String
    @Binding var selection: String
    let options: [PickerOption]
    
    private var selectedTitle: String? {
        options.first { ($0.value as? String) == selection }?.title
    }
    
    var body: some View {
        Picker(selection: $selection) {
            ForEach(options) { option in
                if let stringValue = option.value as? String {
                    Text(option.title).tag(stringValue)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                Text(title)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
                
                if let current = selectedTitle {
                    Text(current)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.disabledText)
            }
            .contentShape(Rectangle())
        }
        .pickerStyle(.menu)
        .tint(AppColors.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Toggle Row (Simple)

/// Reusable toggle row for settings (without subtitle, used in SigningView).
/// The whole row is the toggle's label so tapping anywhere on the row flips it.
struct SimpleToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(width: 24)
                
                Text(title)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .tint(AppColors.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Dylib Row

/// Reusable row for displaying dylib information (basic version)
struct DylibRow: View {
    let name: String
    let size: Int64?
    let isInjected: Bool
    let architecture: String?
    
    var body: some View {
        HStack {
            Image(systemName: "cube")
                .font(.system(size: 14))
                .foregroundColor(isInjected ? AppColors.success : ThemeManager.shared.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                
                if let arch = architecture {
                    Text(arch)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
            
            if let size = size {
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Available Dylib Row

/// Reusable row for displaying available dylibs with selection
struct AvailableDylibRow: View {
    let dylib: DylibFile
    let isSelected: Bool
    var onToggle: (() -> Void)? = nil
    
    var body: some View {
        if let onToggle = onToggle {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(ThemeManager.shared.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dylib.name)
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(dylib.formattedSize)
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(
                    isSelected ? ThemeManager.shared.accentColor.opacity(0.1) : .clear
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            HStack {
                Image(systemName: "cube")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeManager.shared.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(dylib.name)
                        .font(AppFont.body)
                        .foregroundColor(AppColors.primaryText)
                    
                    Text(dylib.formattedSize)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ThemeManager.shared.accentColor)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Detailed Dylib Row

/// Reusable row for displaying dylib information (detailed version with size and architecture)
struct DetailedDylibRow: View {
    let name: String
    let size: Int64
    let isInjected: Bool
    let architecture: String
    
    var body: some View {
        HStack {
            Image(systemName: "cube")
                .font(.system(size: 14))
                .foregroundColor(isInjected ? AppColors.success : ThemeManager.shared.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                
                HStack(spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Text(architecture)
                        .font(AppFont.small)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            
            Spacer()
            
            if isInjected {
                StatusBadge(text: "Injected", color: AppColors.success)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Keyboard Dismissal Extension

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Conditional View Modifier

extension View {
    /// Applies the given transform if the condition is true
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
