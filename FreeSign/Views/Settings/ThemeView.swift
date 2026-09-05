import SwiftUI
import PhotosUI

// MARK: - ThemeView

/// Comprehensive theme customization view with all options from Feather and ZSign
struct ThemeView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var settings = Settings.shared
    
    // Photo picker state
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showRemovePhotoAlert = false
    @State private var showColorPicker = false
    @State private var customColor: Color = Color(hex: "#B87333")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Theme Presets
                presetsSection
                
                // Custom Accent Color (NEW)
                if theme.preset == .custom {
                    customAccentSection
                }
                
                // Background Section
                backgroundSection
                
                // Card Style Section
                cardStyleSection
                
                // App Icon Style (Feather feature)
                appIconStyleSection

                // Preview Section
                previewSection
                
                Spacer(minLength: 40)
            }
            .padding(.vertical, 16)
        }
        .scrollContentBackground(.hidden)
        .background(ThemeManager.shared.backgroundView)
        .appNavigationTitle("Theme & Appearance")
        .appNavigationStyle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TabAssistantButton(sourceView: "Theme", summary: themeAssistantSummary)
            }
        }
        // Process the picked photo
        .onChange(of: photoPickerItem) { item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else { return }
                await MainActor.run {
                    theme.setPhoto(image)
                    customColor = theme.accentColor
                }
            }
            photoPickerItem = nil
        }
        .alert("Remove Background Photo?", isPresented: $showRemovePhotoAlert) {
            Button("Remove", role: .destructive) { theme.removePhoto() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(color: $customColor, onDone: { newColor in
                theme.customAccentHex = newColor.toHex()
                showColorPicker = false
            })
        }
    }

    // MARK: - Assistant

    private var themeAssistantSummary: String {
        return "Theme view: current preset is \(theme.preset.displayName), " +
               "card style: \(theme.cardStyle), " +
               "app icon style: \(theme.appIconStyle), " +
               "background: \(theme.hasPhoto ? "photo" : "solid color")."
    }

    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "paintpalette")
                .font(.system(size: 28))
                .foregroundColor(theme.accentColor)
            
            Text("Theme & Appearance")
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
            
            Text("Customize the look and feel of FreeSign")
                .font(AppFont.body)
                .foregroundColor(AppColors.secondaryText)
        }
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Theme Presets")
            
            // Preset grid
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 8)
            ], spacing: 8) {
                ForEach(ThemePreset.allCases, id: \.self) { preset in
                    Button {
                        theme.preset = preset
                        if preset != .custom {
                            customColor = Color(hex: preset.accentHex)
                        }
                    } label: {
                        PresetPill(
                            preset: preset,
                            theme: theme,
                            isSelected: theme.preset == preset
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(preset.displayName) theme")
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Custom Accent Color Section (NEW)
    
    private var customAccentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Custom Accent Color")
            
            VStack(spacing: 16) {
                // Current color preview
                HStack(spacing: 12) {
                    // Color swatch
                    RoundedRectangle(cornerRadius: 12)
                        .fill(customColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    
                    // Color info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accent Color")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text(customColor.toHex())
                            .font(AppFont.small)
                            .foregroundColor(AppColors.secondaryText)
                            .monospaced()
                    }
                    
                    Spacer()
                    
                    // Change button
                    Button {
                        showColorPicker = true
                    } label: {
                        Text("Change")
                            .font(AppFont.caption)
                            .foregroundColor(theme.accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(AppColors.cardBorder)
                    .padding(.leading, 16)
                
                // Color presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(customColorPresets, id: \.self) { colorHex in
                            Button {
                                customColor = Color(hex: colorHex)
                                theme.customAccentHex = colorHex
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                customColor.toHex() == colorHex 
                                                    ? theme.accentColor 
                                                    : Color.clear, 
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // Custom color presets
    private var customColorPresets: [String] {
        [
            "#B87333", // Bronze (default)
            "#D4924A", // Bronze Light
            "#C9A84C", // Gold
            "#6366F1", // Indigo
            "#8B5CF6", // Violet
            "#EC4899", // Pink
            "#EF4444", // Red
            "#F97316", // Orange
            "#EAB308", // Yellow
            "#22C55E", // Green
            "#14B8A6", // Teal
            "#06B6D4", // Cyan
            "#0EA5E9", // Sky Blue
            "#3B82F6", // Blue
            "#9CA3AF"  // Gray
        ]
    }
    
    // MARK: - Background Section
    
    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Background")
            
            VStack(spacing: 14) {
                // Photo thumbnail or empty state
                ZStack(alignment: .bottomTrailing) {
                    if let img = theme.photo {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(theme.photoDim))
                            )
                            .blur(radius: theme.photoBlur * 0.3)  // preview blur scaled down
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ThemeManager.shared.surfaceColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                            .frame(height: 160)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundColor(AppColors.disabledText)
                                    Text("No background photo")
                                        .font(AppFont.caption)
                                        .foregroundColor(AppColors.disabledText)
                                }
                            )
                    }
                    
                    // Pick / Change / Remove buttons overlay
                    HStack(spacing: 8) {
                        if theme.hasPhoto {
                            Button(role: .destructive) {
                                showRemovePhotoAlert = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(AppFont.small)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .foregroundColor(AppColors.destructive)
                            }
                        }
                        
                        PhotosPicker(
                            selection: $photoPickerItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(theme.hasPhoto ? "Change" : "Choose Photo",
                                  systemImage: "photo.badge.plus")
                                .font(AppFont.small)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .foregroundColor(AppColors.primaryText)
                        }
                    }
                    .padding(10)
                }
                .padding(.horizontal, 16)
                
                // Controls — only visible when a photo is set
                if theme.hasPhoto {
                    VStack(spacing: 12) {
                        PhotoSlider(label: "Blur",    systemImage: "camera.filters",       value: $theme.photoBlur,    range: 0...30)
                        PhotoSlider(label: "Dim",     systemImage: "circle.lefthalf.filled", value: $theme.photoDim,  range: 0...0.9)
                        PhotoSlider(label: "Opacity", systemImage: "circle.dotted",         value: $theme.photoOpacity, range: 0.2...1)
                    }
                    .padding(16)
                    .background(ThemeManager.shared.surfaceColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: theme.hasPhoto)
    }
    
    // MARK: - Card Style Section
    
    private var cardStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Card Style")
            
            VStack(spacing: 1) {
                ForEach(ThemeCardStyle.allCases, id: \.self) { style in
                    Button {
                        theme.cardStyle = style
                    } label: {
                        CardStyleOption(
                            style: style,
                            theme: theme,
                            isSelected: theme.cardStyle == style
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Use \(style.displayName) card style")
                }
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - App Icon Style Section (Feather feature)
    
    private var appIconStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("App Icon Style")
            
            VStack(spacing: 1) {
                ForEach(AppIconStyle.allCases, id: \.self) { style in
                    Button {
                        theme.appIconStyle = style
                    } label: {
                        AppIconStyleOption(
                            style: style,
                            theme: theme,
                            isSelected: theme.appIconStyle == style
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Use \(style.displayName) app icon style")
                }
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - App Display Options Section

    private var appDisplayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("App Display Options")

            VStack(spacing: 1) {
                // Show App Icons
                ToggleRow(
                    icon: "app.fill",
                    title: "Show App Icons",
                    subtitle: "Display app icons in lists",
                    isOn: Binding(
                        get: { theme.showAppIcons },
                        set: { theme.showAppIcons = $0 }
                    )
                )
            }
            .background(ThemeManager.shared.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Preview")
            
            VStack(spacing: 16) {
                // Sample app card with current theme
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: theme.cardStyle == .glass ? 16 : 14)
                                .fill(ThemeManager.shared.surfaceColor)
                                .frame(width: 52, height: 52)
                                .overlay {
                                    if theme.cardStyle == .glass {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            .blur(radius: 10)
                                    } else {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(AppColors.cardBorder, lineWidth: 1)
                                    }
                                }
                            
                            Image(systemName: "app.fill")
                                .font(.system(size: 20))
                                .foregroundColor(theme.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sample App")
                                .font(AppFont.headline)
                                .foregroundColor(AppColors.primaryText)
                            Text("com.example.app")
                                .font(AppFont.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text("v1.0.0")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.disabledText)
                    }
                    
                    // Sample settings card
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accentColor)
                        
                        Text("Theme Settings")
                            .font(AppFont.body)
                            .foregroundColor(AppColors.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.disabledText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ThemeManager.shared.surfaceColor)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cardStyle == .glass ? 16 : 14))
                    .overlay {
                        if theme.cardStyle == .glass {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                .blur(radius: 10)
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        }
                    }
                }
                .padding(16)
                .background(ThemeManager.shared.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                
                Text("Current theme: \(theme.preset.displayName)")
                    .font(AppFont.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(AppFont.title)
                .foregroundColor(AppColors.primaryText)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preset Pill

private struct PresetPill: View {
    let preset: ThemePreset
    @ObservedObject var theme: ThemeManager
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(preset.swatchColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? .white : preset.swatchColor.opacity(0.3),
                                lineWidth: 2
                            )
                    )
                
                if isSelected {
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .fill(preset.swatchColor)
                                .frame(width: 8, height: 8)
                        )
                }
            }
            
            Text(preset.displayName)
                .font(AppFont.small)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .lineLimit(1)
                .frame(width: 70)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                LinearGradient(
                    colors: [preset.swatchColor, preset.swatchColor.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                ThemeManager.shared.surfaceColor
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? preset.swatchColor : AppColors.cardBorder,
                    lineWidth: 1
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Card Style Option

private struct CardStyleOption: View {
    let style: ThemeCardStyle
    @ObservedObject var theme: ThemeManager
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: style == .glass ? 16 : 14)
                    .fill(ThemeManager.shared.surfaceColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if style == .glass {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                .blur(radius: 10)
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        }
                    }
                
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(style.displayName)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(style == .glass ? "Frosted glass effect" : "Classic outlined cards")
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? theme.accentColor.opacity(0.1) : .clear
        )
    }
}

// MARK: - App Icon Style Option

private struct AppIconStyleOption: View {
    let style: AppIconStyle
    @ObservedObject var theme: ThemeManager
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeManager.shared.surfaceColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                
                Image(systemName: iconForStyle(style))
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(style.displayName)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitleForStyle(style))
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? theme.accentColor.opacity(0.1) : .clear
        )
    }
    
    private func iconForStyle(_ style: AppIconStyle) -> String {
        switch style {
        case .system: return "app"
        case .rounded: return "app.fill"
        case .squared: return "square.fill"
        }
    }
    
    private func subtitleForStyle(_ style: AppIconStyle) -> String {
        switch style {
        case .system: return "System default icons"
        case .rounded: return "Rounded corner icons"
        case .squared: return "Sharp corner icons"
        }
    }
}

// MARK: - Signing Behavior Option

private struct SigningBehaviorOption: View {
    let behavior: SigningBehavior
    @ObservedObject var theme: ThemeManager
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeManager.shared.surfaceColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                
                Image(systemName: iconForBehavior(behavior))
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(behavior.displayName)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitleForBehavior(behavior))
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? theme.accentColor.opacity(0.1) : .clear
        )
    }
    
    private func iconForBehavior(_ behavior: SigningBehavior) -> String {
        switch behavior {
        case .ask: return "questionmark.circle"
        case .auto: return "arrow.clockwise"
        case .manual: return "hand.point.up"
        }
    }
    
    private func subtitleForBehavior(_ behavior: SigningBehavior) -> String {
        switch behavior {
        case .ask: return "Prompt before each signing"
        case .auto: return "Automatically sign all apps"
        case .manual: return "Only manual signing allowed"
        }
    }
}

// MARK: - Repository Behavior Option

private struct RepositoryBehaviorOption: View {
    let behavior: RepositoryBehavior
    @ObservedObject var theme: ThemeManager
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ThemeManager.shared.surfaceColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                
                Image(systemName: iconForBehavior(behavior))
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(behavior.displayName)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                Text(subtitleForBehavior(behavior))
                    .font(AppFont.small)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? theme.accentColor.opacity(0.1) : .clear
        )
    }
    
    private func iconForBehavior(_ behavior: RepositoryBehavior) -> String {
        switch behavior {
        case .autoRefresh: return "arrow.clockwise"
        case .manualRefresh: return "arrow.down"
        case .neverRefresh: return "xmark.circle"
        }
    }
    
    private func subtitleForBehavior(_ behavior: RepositoryBehavior) -> String {
        switch behavior {
        case .autoRefresh: return "Keep repositories up to date"
        case .manualRefresh: return "Refresh only when requested"
        case .neverRefresh: return "Never auto-refresh repositories"
        }
    }
}

// MARK: - Photo Slider

struct PhotoSlider: View {
    let label: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var formattedValue: String {
        switch label {
        case "Blur": return String(format: "%.0f", value)
        case "Dim": return String(format: "%.1f", value)
        case "Opacity": return String(format: "%.1f", value)
        default: return String(format: "%.1f", value)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryText)
            
            Text(label)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            Text(formattedValue)
                .font(AppFont.mono)
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 40, alignment: .trailing)
            
            Slider(value: $value, in: range, step: 0.1)
                .tint(ThemeManager.shared.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Color Picker View

struct ColorPickerView: View {
    @Binding var color: Color
    let onDone: (Color) -> Void
    
    @State private var hexString: String = ""
    @State private var showHexField = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Color wheel preview
                ColorWheel(color: $color)
                    .frame(height: 200)
                    .padding(.horizontal, 20)
                
                // Color sliders
                colorSliders
                
                // Hex field
                hexField
                
                // Presets
                colorPresets
                
                Spacer()
            }
            .padding(.vertical, 16)
            .background(ThemeManager.shared.backgroundView)
            .appNavigationTitle("Color Picker")
            .appNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        // Dismiss without saving
                    }
                    .foregroundColor(AppColors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { 
                        onDone(color)
                    }
                    .foregroundColor(ThemeManager.shared.accentColor)
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
            .onAppear {
                hexString = color.toHex()
            }
            .onChange(of: color) { newColor in
                hexString = newColor.toHex()
            }
        }
    }
    
    private var colorSliders: some View {
        VStack(spacing: 12) {
            ColorSlider(
                label: "Red",
                value: Binding(
                    get: { color.red },
                    set: { color = Color(red: $0, green: color.green, blue: color.blue) }
                ),
                range: 0...1
            )
            
            ColorSlider(
                label: "Green",
                value: Binding(
                    get: { color.green },
                    set: { color = Color(red: color.red, green: $0, blue: color.blue) }
                ),
                range: 0...1
            )
            
            ColorSlider(
                label: "Blue",
                value: Binding(
                    get: { color.blue },
                    set: { color = Color(red: color.red, green: color.green, blue: $0) }
                ),
                range: 0...1
            )
            
            ColorSlider(
                label: "Opacity",
                value: Binding(
                    get: { color.opacity },
                    set: { color = Color(red: color.red, green: color.green, blue: color.blue, opacity: $0) }
                ),
                range: 0...1
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var hexField: some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryText)
            
            Text("Hex")
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
            
            TextField("Hex Color", text: $hexString)
                .font(AppFont.mono)
                .foregroundColor(AppColors.primaryText)
                .textFieldStyle(.plain)
                .frame(width: 100, alignment: .trailing)
                .onChange(of: hexString) { newValue in
                    if newValue.count == 7 {
                        self.color = Color(hex: newValue)
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private var colorPresets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(customColorPresets, id: \.self) { colorHex in
                    Button {
                        color = Color(hex: colorHex)
                    } label: {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(
                                        color.toHex() == colorHex 
                                            ? ThemeManager.shared.accentColor 
                                            : Color.clear, 
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
    
    private var customColorPresets: [String] {
        [
            "#B87333", // Bronze (default)
            "#D4924A", // Bronze Light
            "#C9A84C", // Gold
            "#6366F1", // Indigo
            "#8B5CF6", // Violet
            "#EC4899", // Pink
            "#EF4444", // Red
            "#F97316", // Orange
            "#EAB308", // Yellow
            "#22C55E", // Green
            "#14B8A6", // Teal
            "#06B6D4", // Cyan
            "#0EA5E9", // Sky Blue
            "#3B82F6", // Blue
            "#9CA3AF"  // Gray
        ]
    }
}

// MARK: - Color Wheel

struct ColorWheel: View {
    @Binding var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            
            ZStack {
                // Color wheel background
                ForEach(0..<360, id: \.self) { angle in
                    let hue = Double(angle) / 360.0
                    let saturation: Double = 1.0
                    let brightness: Double = 1.0
                    
                    Path { path in
                        let startAngle = Double(angle) * .pi / 180.0
                        let endAngle = Double(angle + 1) * .pi / 180.0
                        
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: Angle(radians: startAngle),
                            endAngle: Angle(radians: endAngle),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                }
                
                // Center circle (white)
                Circle()
                    .fill(Color.white)
                    .frame(width: radius * 0.2, height: radius * 0.2)
                    .position(center)
                
                // Selection indicator
                let hue = color.hue
                let saturation = color.saturation
                let brightness = color.brightness
                
                let angle = hue * 360 * .pi / 180.0
                let distance = radius * saturation * CGFloat(brightness)
                
                let x = center.x + cos(angle) * distance
                let y = center.y - sin(angle) * distance
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .position(x: x, y: y)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let location = value.location
                                let dx = location.x - center.x
                                let dy = location.y - center.y
                                let distance = sqrt(dx * dx + dy * dy)
                                
                                if distance <= radius {
                                    let angle = atan2(-dy, dx)
                                    let hue = angle < 0 ? angle + 2 * .pi : angle
                                    let saturation = min(distance / radius, 1.0)
                                    let brightness: Double = 1.0
                                    
                                    color = Color(
                                        hue: hue / (2 * .pi),
                                        saturation: saturation,
                                        brightness: brightness
                                    )
                                }
                            }
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Color Slider

struct ColorSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.body)
                .foregroundColor(AppColors.primaryText)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Text(String(format: "%.2f", value))
                .font(AppFont.mono)
                .foregroundColor(AppColors.secondaryText)
                .frame(width: 40, alignment: .trailing)
            
            Slider(value: $value, in: range, step: 0.01)
                .tint(ThemeManager.shared.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    var red: Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return 0
        }
        
        return Double(r)
    }
    
    var green: Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return 0
        }
        
        return Double(g)
    }
    
    var blue: Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return 0
        }
        
        return Double(b)
    }
    
    var opacity: Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return 1
        }
        
        return Double(a)
    }
    
    var hue: Double {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return 0
        }
        
        return Double(h)
    }
    
    var saturation: Double {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return 0
        }
        
        return Double(s)
    }
    
    var brightness: Double {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return 0
        }
        
        return Double(b)
    }
    
    func toHex() -> String {
        let components = UIColor(self).cgColor.components
        let r: CGFloat = components?[0] ?? 0
        let g: CGFloat = components?[1] ?? 0
        let b: CGFloat = components?[2] ?? 0
        
        let hexString = String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
        
        return hexString
    }
    
}

#Preview {
    NavigationStack {
        ThemeView()
    }
}
