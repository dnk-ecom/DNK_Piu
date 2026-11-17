import AppKit
import SwiftUI

/// Canonical Astryx OS Design System Tokens for native macOS interfaces.
public enum AstryxTheme {
    // MARK: - Surfaces
    public static let canvas = Color(hex: "#090A0C")
    public static let panel = Color(hex: "#111317")
    public static let card = Color(hex: "#16181D")
    public static let elevated = Color(hex: "#1E2128")
    public static let overlay = Color(hex: "#090A0C").opacity(0.85)

    // MARK: - Borders
    public static let borderSubtle = Color.white.opacity(0.08)
    public static let borderDefault = Color.white.opacity(0.14)
    public static let borderStrong = Color.white.opacity(0.24)
    public static let borderWidth: CGFloat = 0.8

    // MARK: - Accents
    public static let cyan = Color(hex: "#06B6D4")
    public static let purple = Color(hex: "#A855F7")
    public static let emerald = Color(hex: "#10B981")
    public static let amber = Color(hex: "#F59E0B")
    public static let red = Color(hex: "#EF4444")

    // MARK: - Gradients
    public static let activeGradient = LinearGradient(
        colors: [Color(hex: "#06B6D4"), Color(hex: "#10B981")],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let thinkingGradient = LinearGradient(
        colors: [Color(hex: "#06B6D4"), Color(hex: "#A855F7")],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let thinkingVerticalGradient = LinearGradient(
        colors: [Color(hex: "#06B6D4"), Color(hex: "#A855F7")],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let swallowGradient = LinearGradient(
        colors: [Color(hex: "#06B6D4"), Color(hex: "#10B981")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - AppKit Colors
    public static let nsCanvas = NSColor(hex: "#090A0C")
    public static let nsPanel = NSColor(hex: "#111317")
    public static let nsCard = NSColor(hex: "#16181D")
    public static let nsElevated = NSColor(hex: "#1E2128")
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

extension NSColor {
    convenience init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            srgbRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}
