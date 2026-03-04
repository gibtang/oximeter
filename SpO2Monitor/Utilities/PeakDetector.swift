import Foundation
import Accelerate

class PeakDetector {
    private var lastPeakTime: Double = 0
    private let refractoryPeriod: Double = 0.5

    /// Resets the detector's internal state.
    /// Call this before processing a new recording to avoid state contamination.
    func reset() {
        lastPeakTime = 0
    }

    func detectPeaks(in signal: [Double], samplingRate: Double = 60.0, minimumAmplitude: Double? = nil) -> [Int] {
        var peaks: [Int] = []
        guard signal.count > 2 else { return peaks }

        // Calculate derivative using vDSP for performance
        var derivative = [Double](repeating: 0.0, count: signal.count - 1)
        vDSP_vsubD(signal, 1, Array(signal.dropFirst()), 1, &derivative, 1, vDSP_Length(derivative.count))

        // Compute adaptive amplitude threshold if not provided
        let amplitudeThreshold: Double
        if let threshold = minimumAmplitude {
            amplitudeThreshold = threshold
        } else {
            // Use 10% of signal range as default threshold
            let (minVal, maxVal) = (signal.min() ?? 0, signal.max() ?? 1)
            amplitudeThreshold = 0.1 * (maxVal - minVal)
        }

        // Peak detected when derivative changes from positive to negative
        for i in 1..<derivative.count {
            let currentTime = Double(i) / samplingRate
            let timeSinceLastPeak = currentTime - lastPeakTime

            // Zero crossing from positive to negative with refractory period
            if derivative[i-1] > 0 && derivative[i] <= 0 && timeSinceLastPeak > refractoryPeriod {
                // NOTE: Zero-crossing occurs between i-1 and i, so the true peak lies between these indices.
                // Using i as peak index is a reasonable approximation for high sampling rates.
                // For sub-sample precision, interpolation could be used but is omitted for performance.
                let peakAmplitude = signal[i]
                // Amplitude threshold to avoid noise
                if abs(peakAmplitude) > amplitudeThreshold {
                    peaks.append(i)
                    lastPeakTime = currentTime
                }
            }
        }
        return peaks
    }

    func calculateBPM(peaks: [Int], samplingRate: Double = 60.0) -> Double? {
        guard peaks.count >= 4 else { return nil }
        var intervals: [Double] = []
        for i in 1..<peaks.count {
            let interval = Double(peaks[i] - peaks[i-1]) / samplingRate
            if interval >= 0.3 && interval <= 1.5 {
                intervals.append(interval)
            }
        }
        guard intervals.count >= 3 else { return nil }
        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        let bpm = 60.0 / medianInterval
        if bpm >= 40.0 && bpm <= 200.0 {
            return bpm
        }
        return nil
    }
}
