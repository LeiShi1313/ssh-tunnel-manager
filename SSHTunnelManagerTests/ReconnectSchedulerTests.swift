// SSHTunnelManagerTests/ReconnectSchedulerTests.swift
import XCTest
@testable import SSHTunnelManager

final class ReconnectSchedulerTests: XCTestCase {

    func testBackoffSchedule() {
        let scheduler = ReconnectScheduler()
        XCTAssertEqual(scheduler.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 2), 5.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 3), 10.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 4), 30.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 5), 60.0)
    }

    func testBackoffCapsAt60() {
        let scheduler = ReconnectScheduler()
        XCTAssertEqual(scheduler.delay(forAttempt: 6), 60.0)
        XCTAssertEqual(scheduler.delay(forAttempt: 100), 60.0)
    }

    func testShouldRetryUnlimited() {
        let scheduler = ReconnectScheduler(maxRetries: 0)
        XCTAssertTrue(scheduler.shouldRetry(attempt: 0))
        XCTAssertTrue(scheduler.shouldRetry(attempt: 999))
    }

    func testShouldRetryLimited() {
        let scheduler = ReconnectScheduler(maxRetries: 3)
        XCTAssertTrue(scheduler.shouldRetry(attempt: 0))
        XCTAssertTrue(scheduler.shouldRetry(attempt: 2))
        XCTAssertFalse(scheduler.shouldRetry(attempt: 3))
    }
}
