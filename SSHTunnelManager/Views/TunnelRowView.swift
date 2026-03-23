import SwiftUI

struct TunnelRowView: View {
    let config: TunnelConfig
    let state: TunnelState
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.system(size: 13, weight: .medium))
                Text(config.forwardingSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if case .reconnecting(let attempt) = state {
                Text("retry \(attempt)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Button(action: onToggle) {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? .red : .green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit...") { onEdit() }
            Button("Duplicate") { onDuplicate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var isActive: Bool {
        switch state {
        case .connected, .connecting, .reconnecting:
            return true
        default:
            return false
        }
    }

    private var stateColor: Color {
        switch state {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .reconnecting: return .orange
        case .failed: return .red
        }
    }
}
