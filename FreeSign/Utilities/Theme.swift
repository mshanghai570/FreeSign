import SwiftUI

// MARK: - Color Palette — Aged Bronze Vault

enum AppColors {

    // Backgrounds
    static let background   = Color(hexString: "#0D0D10")   // near-black, deep vault floor
    static let surface      = Color(hexString: "#16161B")   // card surface
    static let surface2     = Color(hexString: "#1D1D25")   // elevated modal / sheet surface
    static let surfaceHover = Color(hexString: "#22222C")   // pressed / hover state

    // Accent — aged bronze / copper
    static let accent       = Color(hexString: "#B87333")   // primary bronze
    static let accentLight  = Color(hexString: "#D4924A")   // highlighted bronze
    static let gold         = Color(hexString: "#C9A84C")   // antique gold for badges

    // Text
    static let primaryText   = Color(hexString: "#EDE8DF")  // warm white
    static let secondaryText = Color(hexString: "#9E9891")  // warm grey
    static let disabledText  = Color(hexString: "#575350")  // dim warm grey
    static let invertedText  = Color(hexString: "#0D0D10")  // text on bright backgrounds

    // Status
    static let destructive  = Color(hexString: "#C0392B")
    static let success      = Color(hexString: "#2E9E5B")
    static let warning      = Color(hexString: "#D4820A")
    static let info         = Color(hexString: "#4A90D9")

    // Structural
    static let cardBorder   = Color(hexString: "#B87333").opacity(0.18) // bronze-tinted border
    static let separator    = Color.white.opacity(0.06)
    static let shimmer      = Color(hexString: "#B87333").opacity(0.08)

    // Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(hexString: "#C9923A"), Color(hexString: "#A86828")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let surfaceGradient = LinearGradient(
        colors: [Color(hexString: "#1D1D25"), Color(hexString: "#16161B")],
        startPoint: .top,
        endPoint: .bottom
    )

    // Expiry status colors
    static func expiryColor(daysLeft: Int) -> Color {
        switch daysLeft {
        case ..<0:       return destructive
        case 0..<14:     return warning
        case 14..<60:    return gold
        default:         return success
        }
    }
}

// MARK: - Hex Color Initializer

extension Color {
    init(hexString: String) {
        let hexValue = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexValue.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Initialize from hex string (e.g. "#B87333")
    init(hex: String) {
        self.init(hexString: hex)
    }
}

// MARK: - Typography — IBM Plex Sans

enum AppFont {
    static let largeTitle = Font.custom("IBMPlexSans-Bold",    size: 28)
    static let title      = Font.custom("IBMPlexSans-SemiBold",size: 20)
    static let headline   = Font.custom("IBMPlexSans-SemiBold",size: 17)
    static let subhead    = Font.custom("IBMPlexSans-Medium",  size: 15)
    static let body       = Font.custom("IBMPlexSans-Regular", size: 15)
    static let button     = Font.custom("IBMPlexSans-Medium",  size: 15)
    static let caption    = Font.custom("IBMPlexSans-Regular", size: 13)
    static let caption2   = Font.custom("IBMPlexSans-Regular", size: 11)
    static let small      = Font.custom("IBMPlexSans-Regular", size: 11)
    static let mono       = Font.custom("IBMPlexMono-Regular", size: 13)
    static let monoSm     = Font.custom("IBMPlexMono-Regular", size: 11)
}

// MARK: - View Modifiers

struct AppNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppNavigationTitle: ViewModifier {
    let title: String
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
            }
        }
    }
}

// MARK: - Card Styles

struct AppCardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}

struct AppInsetCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Button Styles

struct AppPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(AppColors.accentGradient)
            configuration.label
                .font(AppFont.button)
                .foregroundColor(.white)
                .opacity(isLoading ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .opacity(configuration.isPressed ? 0.80 : 1.0)
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.button)
            .foregroundColor(AppColors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.80 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.button)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.destructive)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .opacity(configuration.isPressed ? 0.80 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppIconButtonStyle: ButtonStyle {
    var size: CGFloat = 36
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppColors.primaryText)
            .frame(width: size, height: size)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Section Header

struct AppSectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFont.caption)
            .foregroundColor(AppColors.secondaryText)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(AppFont.small)
            .fontWeight(.semibold)
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Bronze Accent Icon Background

struct AccentIconBackground: View {
    let systemName: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 18
    var color: Color = AppColors.accent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(color.opacity(0.12))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// MARK: - Divider

struct AppDivider: View {
    var leadingPadding: CGFloat = 52
    var body: some View {
        Rectangle()
            .fill(AppColors.separator)
            .frame(height: 1)
            .padding(.leading, leadingPadding)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    var progress: Float? = nil

    var body: some View {
        ZStack {
            AppColors.background.opacity(0.75)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                if let p = progress {
                    VStack(spacing: 12) {
                        ProgressView(value: p)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(AppColors.accent)
                            .frame(height: 4)
                            .clipShape(Capsule())
                        Text("\(Int(p * 100))%")
                            .font(AppFont.caption)
                            .foregroundColor(AppColors.secondaryText)
                            .monospacedDigit()
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(AppColors.accent)
                        .scaleEffect(1.2)
                }

                Text(message)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .modifier(AppCardStyle(padding: 0))
            .padding(28)
        }
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(
                    AppColors.accent.opacity(0.6),
                    AppColors.disabledText.opacity(0.4)
                )

            VStack(spacing: 6) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(message)
                    .font(AppFont.body)
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(AppSecondaryButtonStyle())
                    .frame(width: 180)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - List Style

struct AppListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
    }
}

struct AppListSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(AppColors.surface)
            .listRowSeparatorTint(AppColors.separator)
    }
}

// MARK: - Convenience Extensions

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardStyle(padding: padding))
    }
    func appInsetCard() -> some View {
        modifier(AppInsetCardStyle())
    }
    func appListStyle() -> some View {
        modifier(AppListStyle())
    }
    func appListSectionStyle() -> some View {
        modifier(AppListSectionStyle())
    }
    func appNavigationStyle() -> some View {
        modifier(AppNavigationStyle())
    }
    func appPrimaryButton(isLoading: Bool = false) -> some View {
        buttonStyle(AppPrimaryButtonStyle(isLoading: isLoading))
    }
    func appSecondaryButton() -> some View {
        buttonStyle(AppSecondaryButtonStyle())
    }
    func appDestructiveButton() -> some View {
        buttonStyle(AppDestructiveButtonStyle())
    }
    func appIconButton(size: CGFloat = 36) -> some View {
        buttonStyle(AppIconButtonStyle(size: size))
    }
    func appNavigationTitle(_ title: String) -> some View {
        modifier(AppNavigationTitle(title: title))
    }
    func appSectionHeader() -> some View {
        modifier(AppSectionHeader())
    }
}

// MARK: - UIKit Appearance Bridges

struct TabBarAppearance: UIViewRepresentable {
    static func apply() {
        let app = UITabBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor    = UIColor(AppColors.background)
        app.shadowColor        = UIColor(AppColors.separator)

        let normalFont = UIFont(name: "IBMPlexSans-Regular", size: 11)
            ?? .systemFont(ofSize: 11)
        let selectedFont = UIFont(name: "IBMPlexSans-Medium", size: 11)
            ?? .systemFont(ofSize: 11, weight: .medium)

        let normal = [
            NSAttributedString.Key.font:            normalFont,
            NSAttributedString.Key.foregroundColor: UIColor(AppColors.disabledText)
        ]
        let selected = [
            NSAttributedString.Key.font:            selectedFont,
            NSAttributedString.Key.foregroundColor: UIColor(AppColors.accent)
        ]

        [app.stackedLayoutAppearance,
         app.compactInlineLayoutAppearance,
         app.inlineLayoutAppearance].forEach {
            $0.normal.titleTextAttributes   = normal
            $0.selected.titleTextAttributes = selected
        }

        UITabBar.appearance().standardAppearance    = app
        UITabBar.appearance().scrollEdgeAppearance  = app
    }
    
    func makeUIView(context: Context) -> UIView {
        let app = UITabBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor    = UIColor(AppColors.background)
        app.shadowColor        = UIColor(AppColors.separator)

        let normalFont = UIFont(name: "IBMPlexSans-Regular", size: 11)
            ?? .systemFont(ofSize: 11)
        let selectedFont = UIFont(name: "IBMPlexSans-Medium", size: 11)
            ?? .systemFont(ofSize: 11, weight: .medium)

        let normal = [
            NSAttributedString.Key.font:            normalFont,
            NSAttributedString.Key.foregroundColor: UIColor(AppColors.disabledText)
        ]
        let selected = [
            NSAttributedString.Key.font:            selectedFont,
            NSAttributedString.Key.foregroundColor: UIColor(AppColors.accent)
        ]

        [app.stackedLayoutAppearance,
         app.compactInlineLayoutAppearance,
         app.inlineLayoutAppearance].forEach {
            $0.normal.titleTextAttributes   = normal
            $0.selected.titleTextAttributes = selected
        }

        UITabBar.appearance().standardAppearance    = app
        UITabBar.appearance().scrollEdgeAppearance  = app
        return UIView()
    }
    func updateUIView(_ v: UIView, context: Context) {}
}

struct NavBarAppearance: UIViewRepresentable {
    static func apply() {
        let app = UINavigationBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor = UIColor(AppColors.background)
        app.shadowColor     = UIColor(AppColors.separator)

        let boldFont    = UIFont(name: "IBMPlexSans-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)
        let bigBoldFont = UIFont(name: "IBMPlexSans-Bold",     size: 28) ?? .boldSystemFont(ofSize: 28)

        app.titleTextAttributes = [
            .font:            boldFont,
            .foregroundColor: UIColor(AppColors.primaryText)
        ]
        app.largeTitleTextAttributes = [
            .font:            bigBoldFont,
            .foregroundColor: UIColor(AppColors.primaryText)
        ]

        let btn = UIBarButtonItemAppearance()
        btn.normal.titleTextAttributes = [
            .font:            UIFont(name: "IBMPlexSans-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .foregroundColor: UIColor(AppColors.accent)
        ]
        app.buttonAppearance = btn

        UINavigationBar.appearance().standardAppearance   = app
        UINavigationBar.appearance().compactAppearance    = app
        UINavigationBar.appearance().scrollEdgeAppearance = app
    }
    
    func makeUIView(context: Context) -> UIView {
        let app = UINavigationBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor = UIColor(AppColors.background)
        app.shadowColor     = UIColor(AppColors.separator)

        let boldFont    = UIFont(name: "IBMPlexSans-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)
        let bigBoldFont = UIFont(name: "IBMPlexSans-Bold",     size: 28) ?? .boldSystemFont(ofSize: 28)

        app.titleTextAttributes = [
            .font:            boldFont,
            .foregroundColor: UIColor(AppColors.primaryText)
        ]
        app.largeTitleTextAttributes = [
            .font:            bigBoldFont,
            .foregroundColor: UIColor(AppColors.primaryText)
        ]

        let btn = UIBarButtonItemAppearance()
        btn.normal.titleTextAttributes = [
            .font:            UIFont(name: "IBMPlexSans-Regular", size: 15) ?? .systemFont(ofSize: 15),
            .foregroundColor: UIColor(AppColors.accent)
        ]
        app.buttonAppearance = btn

        UINavigationBar.appearance().standardAppearance   = app
        UINavigationBar.appearance().compactAppearance    = app
        UINavigationBar.appearance().scrollEdgeAppearance = app
        return UIView()
    }
    func updateUIView(_ v: UIView, context: Context) {}
}
