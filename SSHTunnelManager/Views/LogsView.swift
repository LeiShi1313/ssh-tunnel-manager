import SwiftUI

struct LogsView: View {
    @Bindable var manager: TunnelManager

    @State private var filter: LogFilter = .all
    @State private var searchText = ""
    @State private var autoScroll = true

    private var filteredLogs: [TunnelLog] {
        var logs = manager.logStore.logs
        switch filter {
        case .all: break
        case .errors: logs = logs.filter { $0.level == .error }
        case .warnings: logs = logs.filter { $0.level == .warning || $0.level == .error }
        case .info: logs = logs.filter { $0.level == .info }
        }
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) || $0.tunnelName.localizedCaseInsensitiveContains(searchText) }
        }
        return logs
    }

    private var activeTunnelCount: Int {
        manager.states.values.filter { if case .connected = $0 { return true }; return false }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text("Activity Log")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.dsOnSurface)
                            if !manager.logStore.logs.isEmpty {
                                Text("\(manager.logStore.logs.count) entries")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.dsPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.dsPrimary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: { manager.logStore.clear() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Clear")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.dsOnSurfaceVariant)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.dsSurfaceContainerHigh)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Filter tabs
                HStack(spacing: 0) {
                    ForEach(LogFilter.allCases, id: \.self) { tab in
                        Button(action: { filter = tab }) {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(filter == tab ? Color.dsPrimary : Color.dsOnSurfaceVariant)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(filter == tab ? Color.dsPrimary.opacity(0.1) : .clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsOutline)
                        TextField("Filter logs...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.dsSurfaceContainerLow)
                    .clipShape(Capsule())
                    .frame(width: 200)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Metrics row
            metricsRow
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 32)

            // Log table
            if filteredLogs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.dsOutlineVariant)
                    Text(manager.logStore.logs.isEmpty ? "No log entries yet" : "No matching logs")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.dsOnSurfaceVariant)
                    Text("Connect a tunnel to start seeing activity.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsOutlineVariant)
                }
                Spacer()
            } else {
                logTable
            }
        }
        .background(Color.dsSurface)
    }

    private var metricsRow: some View {
        HStack(spacing: 16) {
            MetricPill(icon: "bolt.fill", label: "Active", value: "\(activeTunnelCount)", color: .dsPrimary)
            MetricPill(icon: "doc.text", label: "Log Entries", value: "\(manager.logStore.logs.count)", color: .dsSecondary)
            MetricPill(icon: "exclamationmark.triangle.fill", label: "Errors", value: "\(manager.logStore.logs(level: .error).count)", color: .dsError)
            Spacer()
        }
    }

    private var logTable: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Console header
                    HStack(spacing: 8) {
                        Circle().fill(Color.red.opacity(0.3)).frame(width: 10, height: 10)
                        Circle().fill(Color.orange.opacity(0.3)).frame(width: 10, height: 10)
                        Circle().fill(Color.green.opacity(0.3)).frame(width: 10, height: 10)
                        Text("Console.stdout")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.dsOutline)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.5))

                    ForEach(filteredLogs) { log in
                        LogRow(log: log)
                            .id(log.id)
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .onChange(of: manager.logStore.logs.count) { _, _ in
                if autoScroll, let last = filteredLogs.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Filter

enum LogFilter: String, CaseIterable {
    case all = "All"
    case info = "Info"
    case warnings = "Warnings"
    case errors = "Errors"
}

// MARK: - Subviews

struct LogRow: View {
    let log: TunnelLog

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SS"
        return f
    }()

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            Text(Self.timeFormatter.string(from: log.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.dsOutline)
                .frame(width: 80, alignment: .leading)

            Text(log.level.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(levelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(levelColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 64)

            Text("[\(log.tunnelName)]")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.dsSecondary)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)

            Text(log.message)
                .font(.system(size: 12))
                .foregroundStyle(Color.dsOnSurface)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(logBackground)
        .onHover { isHovered = $0 }
    }

    private var logBackground: Color {
        if log.level == .error {
            return Color.dsError.opacity(0.04)
        }
        return isHovered ? Color.dsSurfaceContainerLow : .clear
    }

    private var levelColor: Color {
        switch log.level {
        case .info: return .dsPrimary
        case .debug: return .dsTertiary
        case .warning: return .orange
        case .error: return .dsError
        }
    }
}

struct MetricPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.dsOnSurfaceVariant)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.dsOnSurface)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
    }
}
