import XCTest
@testable import SpO2Monitor

@MainActor
final class MotionManagerTests: XCTestCase {
    func testMotionVarianceCalculation() async {
        let manager = MotionManager()
        await manager.startMonitoring()

        // Wait for baseline
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s

        let variance = await manager.getCurrentMotionVariance()
        XCTAssertGreaterThanOrEqual(variance, 0.0)

        await manager.stopMonitoring()
    }

    func testMotionThreshold() async {
        let manager = MotionManager()
        await manager.startMonitoring()

        // Should be below threshold when still
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let variance = await manager.getCurrentMotionVariance()
        XCTAssertLessThan(variance, 0.5, "Should be reasonable when device is still")

        await manager.stopMonitoring()
    }
}
