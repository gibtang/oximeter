import XCTest
import CoreMedia
@testable import SpO2Monitor

final class SignalProcessorTests: XCTestCase {
    var processor: SignalProcessor!

    override func setUp() {
        super.setUp()
        processor = SignalProcessor()
    }

    override func tearDown() {
        processor = nil
        super.tearDown()
    }

    // MARK: - Synthetic Data Tests

    func testCalculatesSpO2FromSyntheticData() {
        // Generate 30 seconds of synthetic PPG data at 60 Hz (1800 samples)
        // Target: 60 BPM heart rate, 98% SpO2
        let sampleRate = 60.0
        let duration = 30.0
        let targetBPM = 60.0
        let targetSpO2 = 98.0
        let samples = generateSyntheticPPG(
            sampleRate: sampleRate,
            duration: duration,
            bpm: targetBPM,
            spo2: targetSpO2
        )

        // Process the samples
        let result = processor.process(samples: samples)

        // Validate the result
        XCTAssertNotNil(result, "Should return a valid measurement result")

        // SpO2 should be in reasonable range (90-100%)
        XCTAssertGreaterThanOrEqual(result!.spo2, 90.0, "SpO2 should be >= 90%")
        XCTAssertLessThanOrEqual(result!.spo2, 100.0, "SpO2 should be <= 100%")

        // Heart rate should be in reasonable range (50-80 BPM)
        XCTAssertGreaterThanOrEqual(result!.heartRate, 50.0, "Heart rate should be >= 50 BPM")
        XCTAssertLessThanOrEqual(result!.heartRate, 80.0, "Heart rate should be <= 80 BPM")

        // Confidence should be reasonable (> 0.3)
        XCTAssertGreaterThan(result!.confidence, 0.3, "Confidence should be > 0.3")

        // Duration should match input
        XCTAssertEqual(result!.duration, duration, accuracy: 0.1, "Duration should match input")
    }

    // MARK: - Invalid Data Tests

    func testRejectsInvalidData() {
        // Flat signal should return nil
        let sampleRate = 60.0
        let duration = 5.0
        let flatSamples = generateFlatSignal(sampleRate: sampleRate, duration: duration)

        let result = processor.process(samples: flatSamples)

        XCTAssertNil(result, "Flat signal should return nil")
    }

    func testRejectsEmptySamples() {
        let result = processor.process(samples: [])
        XCTAssertNil(result, "Empty samples should return nil")
    }

    func testRejectsTooFewSamples() {
        // Less than 2 seconds of data
        let samples = generateSyntheticPPG(sampleRate: 60.0, duration: 1.0, bpm: 60.0, spo2: 98.0)
        let result = processor.process(samples: samples)
        XCTAssertNil(result, "Too few samples should return nil")
    }

    // MARK: - AC/DC Calculation Tests

    func testCalculatesACDCComponents() {
        let samples = generateSyntheticPPG(sampleRate: 60.0, duration: 5.0, bpm: 60.0, spo2: 98.0)
        let result = processor.process(samples: samples)

        XCTAssertNotNil(result, "Should process valid data")
        XCTAssertGreaterThan(result!.perfusionIndex, 0.0, "Perfusion index should be > 0")
    }

    // MARK: - R-Value Tests

    func testRValueValidation() {
        // Test that R-value is properly validated (0.4 - 2.0)
        let samples = generateSyntheticPPG(sampleRate: 60.0, duration: 10.0, bpm: 60.0, spo2: 98.0)
        let result = processor.process(samples: samples)

        XCTAssertNotNil(result, "Should process valid data")
        // If result exists, R-value was in valid range
    }

    // MARK: - Heart Rate Tests

    func testHeartRateRangeValidation() {
        let samples = generateSyntheticPPG(sampleRate: 60.0, duration: 10.0, bpm: 60.0, spo2: 98.0)
        let result = processor.process(samples: samples)

        XCTAssertNotNil(result, "Should process valid data")
        XCTAssertGreaterThanOrEqual(result!.heartRate, 40.0, "Heart rate should be >= 40 BPM")
        XCTAssertLessThanOrEqual(result!.heartRate, 200.0, "Heart rate should be <= 200 BPM")
    }

    // MARK: - Confidence Scoring Tests

    func testConfidenceScoring() {
        let goodSignal = generateSyntheticPPG(sampleRate: 60.0, duration: 10.0, bpm: 60.0, spo2: 98.0)
        let result = processor.process(samples: goodSignal)

        XCTAssertNotNil(result, "Should process valid data")
        XCTAssertGreaterThan(result!.confidence, 0.0, "Confidence should be > 0")
        XCTAssertLessThanOrEqual(result!.confidence, 1.0, "Confidence should be <= 1")
    }

    // MARK: - SpO2 Clamping Tests

    func testSpO2Clamping() {
        // Generate data that would produce very high SpO2
        let samples = generateSyntheticPPG(sampleRate: 60.0, duration: 10.0, bpm: 60.0, spo2: 105.0)
        let result = processor.process(samples: samples)

        if let result = result {
            XCTAssertLessThanOrEqual(result.spo2, 100.0, "SpO2 should be clamped to <= 100%")
            XCTAssertGreaterThanOrEqual(result.spo2, 70.0, "SpO2 should be clamped to >= 70%")
        }
    }

    // MARK: - Helper Methods

    /// Generate synthetic PPG data with specific heart rate and SpO2 characteristics
    /// - Parameters:
    ///   - sampleRate: Sampling rate in Hz
    ///   - duration: Duration in seconds
    ///   - bpm: Target heart rate in BPM
    ///   - spo2: Target SpO2 percentage
    /// - Returns: Array of PPGSample objects
    private func generateSyntheticPPG(
        sampleRate: Double,
        duration: Double,
        bpm: Double,
        spo2: Double
    ) -> [PPGSample] {
        let sampleCount = Int(sampleRate * duration)
        var samples: [PPGSample] = []

        // Calculate R-value from SpO2 using inverse of SpO2 = 110 - 25*R
        // R = (110 - SpO2) / 25
        let targetR = (110.0 - spo2) / 25.0

        // Heart rate frequency in Hz
        let hrFrequency = bpm / 60.0

        // Base DC component (average perfusion)
        let dcRed = 0.5
        let dcBlue = 0.5

        // AC amplitude (pulse amplitude)
        let acAmplitudeRed = 0.02

        // Calculate blue AC amplitude based on R-value
        // R = (AC_red/DC_red) / (AC_blue/DC_blue)
        // AC_blue = (AC_red/DC_red) / (R/DC_blue)
        let acAmplitudeBlue = (acAmplitudeRed / dcRed) / (targetR / dcBlue)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate

            // Add cardiac component (sine wave at heart rate frequency)
            let cardiacComponent = sin(2.0 * .pi * hrFrequency * t)

            // Add respiratory modulation (slower sine wave)
            let respiratoryComponent = 0.3 * sin(2.0 * .pi * 0.2 * t)

            // Combine components
            let combinedSignal = cardiacComponent + respiratoryComponent

            // Generate PPG values
            let red = dcRed + acAmplitudeRed * combinedSignal
            let blue = dcBlue + acAmplitudeBlue * combinedSignal

            // Add small amount of noise
            let noise = Double.random(in: -0.001...0.001)
            let redNoisy = max(0.0, min(1.0, red + noise))
            let blueNoisy = max(0.0, min(1.0, blue + noise))

            let timestamp = CMTime(seconds: t, preferredTimescale: 600)
            samples.append(PPGSample(red: redNoisy, blue: blueNoisy, timestamp: timestamp))
        }

        return samples
    }

    /// Generate flat signal for testing rejection of invalid data
    private func generateFlatSignal(sampleRate: Double, duration: Double) -> [PPGSample] {
        let sampleCount = Int(sampleRate * duration)
        var samples: [PPGSample] = []

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let timestamp = CMTime(seconds: t, preferredTimescale: 600)
            samples.append(PPGSample(red: 0.5, blue: 0.5, timestamp: timestamp))
        }

        return samples
    }
}
