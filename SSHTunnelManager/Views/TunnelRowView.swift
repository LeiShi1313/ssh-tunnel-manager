import SwiftUI

struct TunnelRowView: View {
    let config: TunnelConfig
    let state: TunnelState
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: DS.iconCircleSize, height: DS.iconCircleSize)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconForeground)
            }

            // Name and details
            VStack(alignment: .leading, spacing: 3) {
                Text(config.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.dsOnSurface)
                HStack(spacing: 4) {
                    Text(config.forwardingSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                    if case .reconnecting(let attempt) = state {
                        Text("retry \(attempt)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.dsTertiary)
                    }
                }
            }

            Spacer()

            // Status label
            Text(statusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(stateColor)

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { isActive },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .tint(.dsPrimary)
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(isHovered ? Color.dsSurfaceContainerLow : .white.opacity(0.01))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .strokeBorder(isHovered ? Color.dsPrimary.opacity(0.15) : .clear, lineWidth: 1)
        )
        .opacity(isActive ? 1.0 : 0.7)
        .onHover { isHovered = $0 }
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

    private var iconName: String {
        switch state {
        case .connected: return "bolt.fill"
        case .connecting, .reconnecting: return "arrow.triangle.2.circlepath"
        case .disconnected: return "cloud.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var iconBackground: Color {
        switch state {
        case .connected: return .dsPrimary.opacity(0.12)
        case .connecting, .reconnecting: return .dsTertiary.opacity(0.12)
        case .disconnected: return .dsOnSurfaceVariant.opacity(0.08)
        case .failed: return .dsError.opacity(0.12)
        }
    }

    private var iconForeground: Color {
        switch state {
        case .connected: return .dsPrimary
        case .connecting, .reconnecting: return .dsTertiary
        case .disconnected: return .dsOnSurfaceVariant
        case .failed: return .dsError
        }
    }

    private var statusText: String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting"
        case .disconnected: return "Stopped"
        case .failed: return "Failed"
        }
    }

    private var stateColor: Color {
        switch state {
        case .disconnected: return .dsOnSurfaceVariant
        case .connecting: return .dsTertiary
        case .connected: return .dsPrimary
        case .reconnecting: return .orange
        case .failed: return .dsError
        }
    }
}
