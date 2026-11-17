import AppKit
import Combine
import SwiftUI

/// Available UI Theme presets for DNK_Piu matching DNK OS & Shopify Research.
public enum AppThemeMode: String, CaseIterable, Identifiable {
    case shopify = "shopify"
    case obsidian = "obsidian"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .shopify: return "Shopify Open Design (Electric Mint & Forest Teal)"
        case .obsidian: return "Astryx Obsidian (Cold Slate & Cyan)"
        }
    }
}

/// Central Theme Manager managing the active palette across DNK_Piu.
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @Published public var mode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "dnk_piu_theme_mode")
            NotificationCenter.default.post(name: .themeDidChange, object: mode)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "dnk_piu_theme_mode") ?? AppThemeMode.shopify.rawValue
        self.mode = AppThemeMode(rawValue: saved) ?? .shopify
    }

    public func setMode(_ newMode: AppThemeMode) {
        self.mode = newMode
    }
}

extension Notification.Name {
    public static let themeDidChange = Notification.Name("dnk_piu_themeDidChange")
}

/// Canonical Design System Tokens for native macOS interfaces.
public enum AstryxTheme {
    // Current Active Mode
    public static var mode: AppThemeMode {
        ThemeManager.shared.mode
    }

    // MARK: - Surfaces
    public static var canvas: Color {
        mode == .shopify ? Color(hex: "#02090A") : Color(hex: "#090A0C")
    }

    public static var panel: Color {
        mode == .shopify ? Color(hex: "#061A1C") : Color(hex: "#111317")
    }

    public static var card: Color {
        mode == .shopify ? Color(hex: "#0C2322") : Color(hex: "#16181D")
    }

    public static var elevated: Color {
        mode == .shopify ? Color(hex: "#102620") : Color(hex: "#1E2128")
    }

    public static var overlay: Color {
        mode == .shopify ? Color(hex: "#02090A").opacity(0.85) : Color(hex: "#090A0C").opacity(0.85)
    }

    // MARK: - Borders
    public static var borderSubtle: Color {
        mode == .shopify ? Color(hex: "#1E2C31").opacity(0.85) : Color.white.opacity(0.08)
    }

    public static var borderDefault: Color {
        mode == .shopify ? Color(hex: "#2A3E45") : Color.white.opacity(0.14)
    }

    public static var borderStrong: Color {
        mode == .shopify ? Color(hex: "#36F4A4").opacity(0.40) : Color.white.opacity(0.24)
    }

    public static let borderWidth: CGFloat = 0.8

    // MARK: - Signature Shopify & Astryx Accents
    public static var accent: Color {
        mode == .shopify ? Color(hex: "#36F4A4") : Color(hex: "#06B6D4") // Electric Mint vs Cyan
    }

    public static var secondaryAccent: Color {
        mode == .shopify ? Color(hex: "#008060") : Color(hex: "#10B981") // Polaris Emerald vs Emerald
    }

    public static var accentText: Color {
        mode == .shopify ? Color(hex: "#000000") : Color(hex: "#08090D")
    }

    public static let cyan = Color(hex: "#06B6D4")
    public static let purple = Color(hex: "#A855F7")
    public static let emerald = Color(hex: "#10B981")
    public static let shopifyMint = Color(hex: "#36F4A4")
    public static let shopifyForest = Color(hex: "#008060")
    public static let amber = Color(hex: "#F59E0B")
    public static let red = Color(hex: "#EF4444")

    // MARK: - Gradients
    public static var activeGradient: LinearGradient {
        if mode == .shopify {
            return LinearGradient(
                colors: [Color(hex: "#36F4A4"), Color(hex: "#008060")],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#06B6D4"), Color(hex: "#10B981")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    public static var thinkingGradient: LinearGradient {
        if mode == .shopify {
            return LinearGradient(
                colors: [Color(hex: "#36F4A4"), Color(hex: "#008060")],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#06B6D4"), Color(hex: "#A855F7")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    public static var thinkingVerticalGradient: LinearGradient {
        if mode == .shopify {
            return LinearGradient(
                colors: [Color(hex: "#36F4A4"), Color(hex: "#008060")],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#06B6D4"), Color(hex: "#A855F7")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    public static var swallowGradient: LinearGradient {
        if mode == .shopify {
            return LinearGradient(
                colors: [Color(hex: "#36F4A4"), Color(hex: "#008060")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#06B6D4"), Color(hex: "#10B981")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - AppKit Colors
    public static var nsCanvas: NSColor {
        mode == .shopify ? NSColor(hex: "#02090A") : NSColor(hex: "#090A0C")
    }

    public static var nsPanel: NSColor {
        mode == .shopify ? NSColor(hex: "#061A1C") : NSColor(hex: "#111317")
    }

    public static var nsCard: NSColor {
        mode == .shopify ? NSColor(hex: "#0C2322") : NSColor(hex: "#16181D")
    }

    public static var nsElevated: NSColor {
        mode == .shopify ? NSColor(hex: "#102620") : NSColor(hex: "#1E2128")
    }
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
