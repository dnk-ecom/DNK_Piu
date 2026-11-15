import AppKit
import PiuCore
import SwiftUI

public struct RequestCardView: View {
    @ObservedObject public var store: PiuStore
    public var request: PendingRequest
    @LocalState private var showNote = false

    public init(store: PiuStore, request: PendingRequest) {
        self.store = store
        self.request = request
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Tool and timestamp
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.25))
                Text(Format.toolName(request.toolName))
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(Format.ago(request.createdAt, now: store.now))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Summary (Command or path)
            if !request.summary.isEmpty {
                Text(request.summary)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
            }

            // Description / Note if present
            if !request.note.isEmpty {
                Text(request.note)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: { store.allow(request) }) {
                    Label("Allow", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.18, green: 0.75, blue: 0.45))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: { store.deny(request) }) {
                    Label("Deny", systemImage: "xmark.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { store.alwaysAllow(request) }) {
                    Text("Always")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
