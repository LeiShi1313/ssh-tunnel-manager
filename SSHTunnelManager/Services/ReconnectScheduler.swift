// SSHTunnelManager/Services/ReconnectScheduler.swift
import Foundation

class ReconnectScheduler {
    private static let backoffSchedule: [TimeInterval] = [1, 2, 5, 10, 30, 60]
    let maxRetries: Int  // 0 = unlimited

    init(maxRetries: Int = 0) {
        self.maxRetries = maxRetries
    }

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let index = min(attempt, Self.backoffSchedule.count - 1)
        return Self.backoffSchedule[index]
    }

    func shouldRetry(attempt: Int) -> Bool {
        if maxRetries == 0 { return true }
        return attempt < maxRetries
    }

    func scheduleRetry(attempt: Int, action: @escaping () -> Void) -> DispatchWorkItem? {
        guard shouldRetry(attempt: attempt) else { return nil }
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay(forAttempt: attempt), execute: item)
        return item
    }
}
