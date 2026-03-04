import Foundation
import Accelerate
import CoreMedia

/// Signal processor for calculating SpO2 and heart rate from PPG samples
///
/// This actor processes PPG photoplethysmogram data through the following pipeline:
/// 1. Bandpass filtering to extract cardiac components
/// 2. AC/DC component extraction using vDSP
/// 3. R-value calculation from red/blue channel ratios
/// 4. SpO2 estimation using empirical formula
/// 5. Heart rate calculation from peak detection
/// 6. Confidence scoring based on signal quality
actor SignalProcessor {
    // MARK: - Properties

    private let filter: PPGFilter
    private let peakDetector: PeakDetector
    private let samplingRate: Double = 60.0
    private let minimumDuration: TimeInterval = 2.0 // Minimum 2 seconds of data

    // R-value validation limits
    private let minRValue: Double = 0.4
    private let maxRValue: Double = 2.0

    // SpO2 calculation limits
    private let minSpO2: Double = 70.0
    private let maxSpO2: Double = 100.0

    // Heart rate limits (BPM)
    private let minHeartRate: Double = 40.0
    private let maxHeartRate: Double = 200.0

    // Perfusion index threshold
    private let minPerfusionIndex: Double = 0.01

    // MARK: - Initialization

    init(filter: PPGFilter = PPGFilter(), peakDetector: PeakDetector = PeakDetector()) {
        self.filter = filter
        self.peakDetector = peakDetector
    }

    // MARK: - Public Methods

    /// Process PPG samples and extract SpO2 and heart rate measurements
    /// - Parameter samples: Array of PPGSample objects containing red and blue channel data
    /// - Returns: MeasurementResult if successful, nil if signal quality is insufficient
    func process(samples: [PPGSample]) -> MeasurementResult? {
        // Validate input
        guard samples.count >= Int(samplingRate * minimumDuration) else {
            return nil
        }

        // Extract red and blue signals
        let redSignal = samples.map { $0.red }
        let blueSignal = samples.map { $0.blue }

        // Filter signals
        let filteredRed = filter.process(signal: redSignal)
        let filteredBlue = filter.process(signal: blueSignal)

        // Calculate AC/DC components for red channel
        guard let (acRed, dcRed, piRed) = calculateACDC(signal: filteredRed) else {
            return nil
        }

        // Calculate AC/DC components for blue channel
        guard let (acBlue, dcBlue, piBlue) = calculateACDC(signal: filteredBlue) else {
            return nil
        }

        // Calculate perfusion index (use the better of the two channels)
        let perfusionIndex = max(piRed, piBlue)

        // Validate perfusion index
        guard perfusionIndex > minPerfusionIndex else {
            return nil
        }

        // Calculate R-value
        guard let rValue = calculateRValue(
            acRed: acRed, dcRed: dcRed,
            acBlue: acBlue, dcBlue: dcBlue
        ) else {
            return nil
        }

        // Calculate SpO2 from R-value
        let spo2 = calculateSpO2(rValue: rValue)

        // Detect peaks and calculate heart rate from red channel
        peakDetector.reset()
        let peaks = peakDetector.detectPeaks(in: filteredRed, samplingRate: samplingRate)

        guard let heartRate = peakDetector.calculateBPM(peaks: peaks, samplingRate: samplingRate) else {
            return nil
        }

        // Calculate confidence score
        let confidence = calculateConfidence(
            perfusionIndex: perfusionIndex,
            peakCount: peaks.count,
            duration: Double(samples.count) / samplingRate
        )

        // Calculate signal-to-noise ratio
        let snr = calculateSNR(signal: filteredRed, peaks: peaks)

        // Calculate duration
        let duration = Double(samples.count) / samplingRate

        return MeasurementResult(
            spo2: spo2,
            heartRate: heartRate,
            confidence: confidence,
            duration: duration,
            perfusionIndex: perfusionIndex,
            signalToNoiseRatio: snr
        )
    }

    // MARK: - Private Methods

    /// Calculate AC and DC components from a signal
    /// - Parameter signal: Input signal array
    /// - Returns: Tuple of (AC, DC, perfusionIndex) or nil if calculation fails
    private func calculateACDC(signal: [Double]) -> (ac: Double, dc: Double, perfusionIndex: Double)? {
        guard !signal.isEmpty else { return nil }

        var dc = 0.0
        var centeredSignal = [Double](repeating: 0.0, count: signal.count)

        // Calculate DC component (mean) using vDSP
        vDSP_meanvD(signal, 1, &dc, vDSP_Length(signal.count))

        guard dc != 0 else { return nil }

        // Center the signal by subtracting DC
        var dcNeg = -dc
        vDSP_vsaddD(signal, 1, &dcNeg, &centeredSignal, 1, vDSP_Length(signal.count))

        // Calculate AC component (RMS) using vDSP
        var ac = 0.0
        vDSP_rmsqvD(centeredSignal, 1, &ac, vDSP_Length(centeredSignal.count))

        // Calculate perfusion index
        let perfusionIndex = ac / dc

        return (ac, dc, perfusionIndex)
    }

    /// Calculate R-value from AC/DC components
    /// R = (AC_red/DC_red) / (AC_blue/DC_blue)
    private func calculateRValue(
        acRed: Double, dcRed: Double,
        acBlue: Double, dcBlue: Double
    ) -> Double? {
        guard dcRed != 0, dcBlue != 0 else { return nil }

        let ratioRed = acRed / dcRed
        let ratioBlue = acBlue / dcBlue

        guard ratioBlue != 0 else { return nil }

        let rValue = ratioRed / ratioBlue

        // Validate R-value is in acceptable range
        guard rValue >= minRValue, rValue <= maxRValue else {
            return nil
        }

        return rValue
    }

    /// Calculate SpO2 from R-value using empirical formula
    /// SpO2 = 110 - 25 * R
    private func calculateSpO2(rValue: Double) -> Double {
        let spo2 = 110.0 - (25.0 * rValue)
        return max(minSpO2, min(maxSpO2, spo2))
    }

    /// Calculate confidence score based on various signal quality metrics
    private func calculateConfidence(
        perfusionIndex: Double,
        peakCount: Int,
        duration: TimeInterval
    ) -> Double {
        var confidence = 0.0

        // Perfusion index score (higher is better, typical range 0.01-0.1)
        let perfusionScore = min(perfusionIndex / 0.05, 1.0)
        confidence += perfusionScore * 0.4

        // Peak count score (should have reasonable number of peaks for duration)
        let expectedPeaks = Int(duration * 60.0 / 60.0) // Assuming 60 BPM
        let peakRatio = Double(peakCount) / Double(max(expectedPeaks, 1))
        let peakScore = 1.0 - abs(1.0 - min(peakRatio, 2.0))
        confidence += peakScore * 0.4

        // Duration score (longer is better, up to 30 seconds)
        let durationScore = min(duration / 30.0, 1.0)
        confidence += durationScore * 0.2

        return max(0.0, min(1.0, confidence))
    }

    /// Calculate signal-to-noise ratio
    private func calculateSNR(signal: [Double], peaks: [Int]) -> Double {
        guard !signal.isEmpty, !peaks.isEmpty else { return 0.0 }

        // Calculate signal power around peaks
        var signalPower = 0.0
        var noisePower = 0.0
        var signalCount = 0
        var noiseCount = 0

        let windowSize = 10 // samples

        for peak in peaks {
            let start = max(0, peak - windowSize)
            let end = min(signal.count, peak + windowSize + 1)

            for i in start..<end {
                let distance = abs(i - peak)
                if distance <= windowSize / 2 {
                    signalPower += signal[i] * signal[i]
                    signalCount += 1
                } else {
                    noisePower += signal[i] * signal[i]
                    noiseCount += 1
                }
            }
        }

        guard signalCount > 0, noiseCount > 0 else { return 0.0 }

        let avgSignalPower = signalPower / Double(signalCount)
        let avgNoisePower = noisePower / Double(noiseCount)

        guard avgNoisePower > 0 else { return 0.0 }

        let snr = 10.0 * log10(avgSignalPower / avgNoisePower)
        return max(0.0, snr)
    }
}
