import Foundation

/// The look of one session's visualizer orb/avatar.
public struct BuddyTraits: Equatable {
    public enum Shape: Int, CaseIterable { case orb, spark, shield, cube }

    public static let colorCount = 8
    public static let names = [
        "Gerych", "Denchik", "Antigravity", "Piu", "Apex", "Nova", "Vector", "Orbit",
        "Kuzma", "Matrix", "Pulse", "Zenith", "Atlas", "Echo", "Falcon", "Helios"
    ]

    public var shape: Shape
    public var color: Int
    public var name: String
    public var phase: Double

    public init(seed: String) {
        let hash = Self.fnv1a(seed)
        shape = Shape.allCases[Int(hash % UInt64(Shape.allCases.count))]
        color = Int((hash >> 8) % UInt64(Self.colorCount))
        name = Self.names[Int((hash >> 16) % UInt64(Self.names.count))]
        phase = Double((hash >> 32) % 1000) / 100
    }

    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
