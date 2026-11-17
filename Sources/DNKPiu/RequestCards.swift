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
                    .foregroundColor(Color(hex: "#F97316"))
                    .font(.system(size: 11, weight: .bold))
                Text(Format.toolName(request.toolName))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#F5F6F8"))
                Spacer()
                Text(Format.ago(request.createdAt, now: store.now))
                    .font(.system(size: 9.5))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            // Summary (Command or path)
            if !request.summary.isEmpty {
                Text(request.summary)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Color(hex: "#E8E9EC"))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
            }

            // Description / Note if present
            if !request.note.isEmpty {
                Text(request.note)
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: { store.allow(request) }) {
                    Label("Allow", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#10B981"))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: { store.deny(request) }) {
                    Label("Deny", systemImage: "xmark.circle")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { store.alwaysAllow(request) }) {
                    Text("Always")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
