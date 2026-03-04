import Foundation
import Accelerate

class PeakDetector {
    private var lastPeakTime: Double = 0
    private let refractoryPeriod: Double = 0.5

    func detectPeaks(in signal: [Double], samplingRate: Double = 60.0) -> [Int] {
        var peaks: [Int] = []
        guard signal.count > 2 else { return peaks }

        // Calculate derivative using vDSP for performance
        var derivative = [Double](repeating: 0.0, count: signal.count - 1)
        vDSP_vsubD(signal, 1, Array(signal.dropFirst()), 1, &derivative, 1, vDSP_Length(derivative.count))

        // Peak detected when derivative changes from positive to negative
        for i in 1..<derivative.count {
            let currentTime = Double(i) / samplingRate
            let timeSinceLastPeak = currentTime - lastPeakTime

            // Zero crossing from positive to negative with refractory period
            if derivative[i-1] > 0 && derivative[i] <= 0 && timeSinceLastPeak > refractoryPeriod {
                let peakAmplitude = signal[i]
                // Amplitude threshold to avoid noise
                if abs(peakAmplitude) > 0.1 {
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
