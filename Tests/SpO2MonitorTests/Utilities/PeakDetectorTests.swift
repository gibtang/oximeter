import XCTest
@testable import SpO2Monitor

final class PeakDetectorTests: XCTestCase {
    func testDetectsSyntheticPeaks() {
        let detector = PeakDetector()
        let sampleRate = 60.0
        var signal = [Double]()
        for i in 0..<300 {
            let t = Double(i) / sampleRate
            signal.append(sin(2.0 * .pi * 1.0 * t))
        }
        let peaks = detector.detectPeaks(in: signal, samplingRate: sampleRate)
        XCTAssertGreaterThanOrEqual(peaks.count, 4, "Should detect at least 4 peaks")
    }

    func testRefractoryPeriod() {
        let detector = PeakDetector()
        let signal = [1.0, 0.5, 1.0, 0.5, 1.0, 0.5]
        let peaks = detector.detectPeaks(in: signal, samplingRate: 60.0)
        XCTAssertLessThan(peaks.count, signal.count)
    }

    func testCalculatesBPM() {
        let detector = PeakDetector()
        let peaks = [0, 60, 120, 180, 240]
        let bpm = detector.calculateBPM(peaks: peaks, samplingRate: 60.0)
        XCTAssertEqual(bpm, 60.0, accuracy: 1.0)
    }

    func testRejectsInvalidBPM() {
        let detector = PeakDetector()
        let peaks = [0, 5, 10, 15]
        let bpm = detector.calculateBPM(peaks: peaks, samplingRate: 60.0)
        XCTAssertNil(bpm, "Should reject unrealistic heart rates")
    }
}
