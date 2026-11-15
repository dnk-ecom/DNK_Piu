import PiuCore
import SwiftUI

public struct BuddyView: View {
    public var traits: BuddyTraits
    public var activity: Activity
    public var size: CGFloat = 36

    public init(traits: BuddyTraits, activity: Activity, size: CGFloat = 36) {
        self.traits = traits
        self.activity = activity
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [pulseColor.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)

            // Core Orb
            Circle()
                .fill(
                    LinearGradient(
                        colors: [pulseColor, pulseColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: pulseColor.opacity(0.5), radius: 4, x: 0, y: 2)

            // Inner symbol / indicator
            innerIcon
        }
    }

    @ViewBuilder
    private var innerIcon: some View {
        switch activity {
        case .needsYou:
            Text("!")
                .font(.system(size: size * 0.5, weight: .black, design: .rounded))
                .foregroundColor(.white)
        case .working:
            Image(systemName: "waveform")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
        case .idle:
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var pulseColor: Color {
        switch activity {
        case .needsYou:
            return Color(red: 0.95, green: 0.35, blue: 0.25) // Vibrant Amber-Red alert
        case .working:
            return Color(red: 0.18, green: 0.83, blue: 0.75) // DNK Cyan / Teal
        case .idle:
            return Color(red: 0.75, green: 0.45, blue: 0.95) // DNK Purple
        }
    }
}
