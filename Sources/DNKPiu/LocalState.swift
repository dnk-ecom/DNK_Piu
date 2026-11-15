import SwiftUI

/// Zero-macro local state wrapper for CommandLineTools builds on macOS 14+.
@propertyWrapper
public struct LocalState<T>: DynamicProperty {
    final class Storage: ObservableObject {
        var value: T
        init(_ value: T) { self.value = value }
    }
    @StateObject private var storage: Storage

    public init(wrappedValue: T) {
        _storage = StateObject(wrappedValue: Storage(wrappedValue))
    }

    public var wrappedValue: T {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { storage.value },
            set: { storage.value = $0 }
        )
    }
}
