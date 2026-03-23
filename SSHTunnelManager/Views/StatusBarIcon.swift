import SwiftUI

struct StatusBarIcon {
    static func systemImageName(for state: AggregateState) -> String {
        "network"
    }

    static func color(for state: AggregateState) -> Color {
        switch state {
        case .idle: return .gray
        case .allConnected: return .green
        case .partial: return .orange
        case .error: return .red
        }
    }
}
