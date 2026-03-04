#!/usr/bin/env swift
import Foundation
import Accelerate

// PPGFilter Implementation
class PPGFilter {
    private var setup: vDSP_biquad_Setup?
    private var delay: [Double]

    // Butterworth Bandpass: Fs=60Hz, Passband=[0.8Hz, 4.0Hz]
    private let coefficients: [Double] = [
        0.020083,  0.0,       -0.020083,  // b0, b1, b2
        1.802656, -0.835824,               // -a1, -a2
        1.0,       0.0,       -1.0,
        1.905203, -0.931505
    ]

    init() {
        self.delay = [Double](repeating: 0.0, count: (2 * 2) + 2)
        self.setup = vDSP_biquad_CreateSetupD(coefficients, vDSP_Length(2))
    }

    func process(signal: [Double]) -> [Double] {
        guard let setup = setup, !signal.isEmpty else { return [] }
        var output = [Double](repeating: 0.0, count: signal.count)
        vDSP_biquadD(setup, &delay, signal, 1, &output, 1, vDSP_Length(signal.count))
        return output
    }

    deinit {
        if let setup = setup {
            vDSP_biquad_DestroySetupD(setup)
        }
    }
}

// Test Framework
struct TestResult {
    let name: String
    let passed: Bool
    let message: String
}

class TestCase {
    var results: [TestResult] = []

    func assert(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        let result = TestResult(
            name: "Assertion at \(file):\(line)",
            passed: condition,
            message: message
        )
        results.append(result)
    }

    func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") {
        let passed = a == b
        let msg = message.isEmpty ? "\(a) == \(b)" : message
        assert(passed, msg)
    }

    func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "") {
        let passed = a > b
        let msg = message.isEmpty ? "\(a) > \(b)" : message
        assert(passed, msg)
    }

    func XCTAssertNotNil(_ value: Any?, _ message: String = "") {
        let passed = value != nil
        let msg = message.isEmpty ? "Value is not nil" : message
        assert(passed, msg)
    }
}

// Test Class
final class PPGFilterTests: TestCase {
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

    func runAllTests() {
        print("Running PPGFilter Tests")
        print("======================")
        print()

        testFilterInitialization()
        testFilterProcessesSignal()
        testFilterFrequencyResponse()

        let passed = results.filter { $0.passed }.count
        let failed = results.filter { !$0.passed }.count

        for result in results {
            let icon = result.passed ? "✅" : "❌"
            print("\(icon) \(result.name): \(result.message)")
        }

        print()
        print("Results: \(passed) passed, \(failed) failed")
        print("======================")
    }
}

// Run tests
let tests = PPGFilterTests()
tests.runAllTests()
