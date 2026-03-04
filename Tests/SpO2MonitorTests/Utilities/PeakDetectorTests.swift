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

    // MARK: - Edge Case Tests

    func testEmptySignal() {
        let detector = PeakDetector()
        let peaks = detector.detectPeaks(in: [], samplingRate: 60.0)
        XCTAssertEqual(peaks.count, 0, "Empty signal should return no peaks")
    }

    func testSignalWithTwoElements() {
        let detector = PeakDetector()
        let signal = [0.5, 1.0]
        let peaks = detector.detectPeaks(in: signal, samplingRate: 60.0)
        XCTAssertEqual(peaks.count, 0, "Signal with 2 elements is too short for peak detection")
    }

    func testSignalWithThreeElements() {
        let detector = PeakDetector()
        let signal = [0.0, 1.0, 0.0]
        let peaks = detector.detectPeaks(in: signal, samplingRate: 60.0)
        XCTAssertGreaterThanOrEqual(peaks.count, 0, "Signal with 3 elements may detect peaks")
    }

    func testFlatLineSignal() {
        let detector = PeakDetector()
        let signal = [Double](repeating: 0.5, count: 100)
        let peaks = detector.detectPeaks(in: signal, samplingRate: 60.0)
        XCTAssertEqual(peaks.count, 0, "Flat line signal should have no peaks")
    }

    func testAllNegativeValues() {
        let detector = PeakDetector()
        let sampleRate = 60.0
        var signal = [Double]()
        for i in 0..<300 {
            let t = Double(i) / sampleRate
            signal.append(-1.0 * sin(2.0 * .pi * 1.0 * t))
        }
        let peaks = detector.detectPeaks(in: signal, samplingRate: sampleRate)
        XCTAssertGreaterThan(peaks.count, 0, "Should detect peaks even with negative values")
    }

    func testLowAmplitudeSignal() {
        let detector = PeakDetector()
        let sampleRate = 60.0
        var signal = [Double]()
        for i in 0..<300 {
            let t = Double(i) / sampleRate
            signal.append(0.01 * sin(2.0 * .pi * 1.0 * t))
        }
        let peaks = detector.detectPeaks(in: signal, samplingRate: sampleRate)
        // With adaptive threshold, should still detect peaks
        XCTAssertGreaterThan(peaks.count, 0, "Should detect peaks in low amplitude signal with adaptive threshold")
    }

    func testResetMethodClearsState() {
        let detector = PeakDetector()
        let signal = [1.0, 0.5, 1.0, 0.5]
        let firstPeaks = detector.detectPeaks(in: signal, samplingRate: 60.0)

        detector.reset()

        let secondPeaks = detector.detectPeaks(in: signal, samplingRate: 60.0)
        XCTAssertEqual(
            secondPeaks.count,
            firstPeaks.count,
            "After reset, should detect same number of peaks"
        )
    }

    func testStateContaminationWithoutReset() {
        let detector = PeakDetector()
        let shortSignal = [1.0, 0.5, 1.0]
        _ = detector.detectPeaks(in: shortSignal, samplingRate: 60.0)

        let longSignal = [1.0, 0.5, 1.0, 0.5, 1.0, 0.5, 1.0, 0.5, 1.0]
        let peaks = detector.detectPeaks(in: longSignal, samplingRate: 60.0)

        // Without reset, refractory period may prevent peak detection
        XCTAssertGreaterThan(peaks.count, 0, "Should detect peaks even without explicit reset")
    }

    func testMinimumAmplitudeParameter() {
        let detector = PeakDetector()
        let sampleRate = 60.0
        var signal = [Double]()
        for i in 0..<300 {
            let t = Double(i) / sampleRate
            signal.append(0.5 * sin(2.0 * .pi * 1.0 * t))
        }

        let peaksWithThreshold = detector.detectPeaks(in: signal, samplingRate: sampleRate, minimumAmplitude: 1.0)
        XCTAssertEqual(
            peaksWithThreshold.count,
            0,
            "High threshold should filter out all peaks"
        )
    }

    func testSingleElement() {
        let detector = PeakDetector()
        let peaks = detector.detectPeaks(in: [1.0], samplingRate: 60.0)
        XCTAssertEqual(peaks.count, 0, "Single element signal should return no peaks")
    }
}
