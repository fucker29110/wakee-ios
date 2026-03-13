import SwiftUI

enum AppTheme {
    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: "#0A0A0A")
        static let surface = Color(hex: "#1A1A1A")
        static let surfaceVariant = Color(hex: "#2A2A2A")
        static let primary = Color.white
        static let secondary = Color(hex: "#9CA3AF")
        static let accent = Color(hex: "#FF6B35")
        static let accentEnd = Color(hex: "#FF8F65")
        static let tabActive = Color.white
        static let tabInactive = Color(hex: "#6B7280")
        static let border = Color(hex: "#2A2A2A")
        static let button = Color(hex: "#3A3A3A")
        static let buttonText = Color.white
        static let danger = Color(hex: "#EF4444")
        static let success = Color(hex: "#22C55E")
        static let badge = Color(hex: "#EF4444")
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Border Radius
    enum BorderRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Font Size
    enum FontSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 48
    }

    // MARK: - Gradient
    static let accentGradient = LinearGradient(
        colors: [Colors.accent, Colors.accentEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Dark TextField Style
struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.BorderRadius.sm)
                    .fill(AppTheme.Colors.surfaceVariant)
            )
            .foregroundColor(AppTheme.Colors.primary)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
