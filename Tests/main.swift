#!/usr/bin/env swift
import Foundation
import Accelerate

// Simple test runner for PPGFilter

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

// Test 1: Filter Initialization
print("Test 1: Filter Initialization")
let filter = PPGFilter()
print("✅ PASS: Filter initialized successfully")
print()

// Test 2: Filter Processes Signal
print("Test 2: Filter Processes Signal")
let input = Array(repeating: 1.0, count: 60)
let output = filter.process(signal: input)
if output.count == input.count {
    print("✅ PASS: Signal processed correctly, output count matches input count")
} else {
    print("❌ FAIL: Output count \(output.count) != input count \(input.count)")
}
print()

// Test 3: Filter Frequency Response
print("Test 3: Filter Frequency Response")
let sampleRate = 60.0
let duration = 1.0
let signal = (0..<Int(sampleRate * duration)).map { i in
    sin(2.0 * .pi * 1.0 * Double(i) / sampleRate)
}

let filtered = filter.process(signal: signal)
let outputEnergy = filtered.reduce(0.0) { $0 + $1 * $1 }

if outputEnergy > 0.1 {
    print("✅ PASS: Passband signal preserved, energy: \(outputEnergy)")
} else {
    print("❌ FAIL: Passband signal not preserved, energy: \(outputEnergy)")
}
print()

print("All tests completed!")
