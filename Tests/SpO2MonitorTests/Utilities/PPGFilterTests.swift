import XCTest
@testable import SpO2Monitor

final class PPGFilterTests: XCTestCase {
    func testFilterInitialization() {
        let filter = PPGFilter()
        XCTAssertNotNil(filter)
    }

    func testFilterProcessesSignal() {
        let filter = PPGFilter()
        let input = Array(repeating: 1.0, count: 60)
        let output = filter.process(signal: input)
        XCTAssertEqual(output.count, input.count)
    }

    func testFilterFrequencyResponse() {
        let filter = PPGFilter()
        // Generate 1Hz sine wave (within passband)
        let sampleRate = 60.0
        let duration = 1.0
        let signal = (0..<Int(sampleRate * duration)).map { i in
            sin(2.0 * .pi * 1.0 * Double(i) / sampleRate)
        }

        let filtered = filter.process(signal: signal)

        // Signal should be preserved (not zeroed)
        let outputEnergy = filtered.reduce(0.0) { $0 + $1 * $1 }
        XCTAssertGreaterThan(outputEnergy, 0.1, "Passband signal should be preserved")
    }
}
