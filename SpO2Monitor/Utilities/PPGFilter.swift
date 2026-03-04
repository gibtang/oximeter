import Foundation
import Accelerate

/// PPG (Photoplethysmography) signal filter using vDSP Accelerate framework
///
/// Implements a Butterworth bandpass filter to extract heart rate signals from camera data.
/// The filter is configured with:
/// - Sampling frequency (Fs): 60Hz
/// - Passband: 0.8Hz - 4.0Hz (corresponding to 48-240 BPM heart rate range)
///
/// The filter uses cascaded biquad sections for efficient real-time processing.
final class PPGFilter {
    private var setup: vDSP_biquad_Setup?
    private var delay: [Double]

    // Butterworth Bandpass: Fs=60Hz, Passband=[0.8Hz, 4.0Hz]
    // Coefficients computed using MATLAB/Octave butter() function
    private let coefficients: [Double] = [
        0.020083,  0.0,       -0.020083,  // b0, b1, b2
        1.802656, -0.835824,               // -a1, -a2
        1.0,       0.0,       -1.0,
        1.905203, -0.931505
    ]

    /// Initializes the PPG filter with vDSP biquad setup
    init() {
        self.delay = [Double](repeating: 0.0, count: (2 * 2) + 2)
        self.setup = vDSP_biquad_CreateSetupD(coefficients, vDSP_Length(2))
    }

    /// Processes a PPG signal through the bandpass filter
    /// - Parameter signal: Input PPG signal samples
    /// - Returns: Filtered signal with heart rate information extracted
    func process(signal: [Double]) -> [Double] {
        guard let setup = setup, !signal.isEmpty else { return [] }
        var output = [Double](repeating: 0.0, count: signal.count)
        vDSP_biquadD(setup, &delay, signal, 1, &output, 1, vDSP_Length(signal.count))
        return output
    }

    /// Cleans up vDSP resources
    deinit {
        if let setup = setup {
            vDSP_biquad_DestroySetupD(setup)
        }
    }
}
