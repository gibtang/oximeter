import Foundation

// Platform-specific implementation using conditional compilation
#if os(iOS)
import CoreMotion

/// Manages motion detection using CoreMotion to identify movement artifacts during measurement.
/// Uses actor-based concurrency for thread-safe access to motion data.
actor MotionManager {
    // MARK: - Properties

    private let motionManager = CMMotionManager()
    private var baselineAcceleration: CMAcceleration?
    private var isMonitoring = false

    // MARK: - Configuration

    /// Update interval for accelerometer readings (in seconds)
    private let accelerometerUpdateInterval: TimeInterval = 0.1 // 10 Hz

    /// Time to wait before capturing baseline acceleration
    private let baselineCaptureDelay: TimeInterval = 1.0

    // MARK: - Public Methods

    /// Starts monitoring device motion using the accelerometer.
    /// Captures a baseline acceleration after a short delay to account for initial settling.
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ Accelerometer not available")
            return
        }

        guard !isMonitoring else {
            print("⚠️ Motion monitoring already active")
            return
        }

        motionManager.accelerometerUpdateInterval = accelerometerUpdateInterval
        motionManager.startAccelerometerUpdates()
        isMonitoring = true

        print("📱 Motion monitoring started at \(1.0/accelerometerUpdateInterval) Hz")

        // Capture baseline after delay to allow for initial settling
        Task {
            try? await Task.sleep(for: .seconds(baselineCaptureDelay))
            if let currentData = motionManager.accelerometerData {
                baselineAcceleration = currentData.acceleration
                print("📊 Baseline acceleration captured: x=\(currentData.acceleration.x), y=\(currentData.acceleration.y), z=\(currentData.acceleration.z)")
            }
        }
    }

    /// Calculates the current motion variance from the baseline.
    /// Returns the Euclidean distance from the baseline acceleration.
    /// - Returns: A Double representing motion variance (0.0 when no motion detected)
    func getCurrentMotionVariance() -> Double {
        guard let current = motionManager.accelerometerData?.acceleration,
              let baseline = baselineAcceleration else {
            return 0.0
        }

        // Calculate Euclidean distance from baseline
        let dx = current.x - baseline.x
        let dy = current.y - baseline.y
        let dz = current.z - baseline.z

        let variance = sqrt(dx * dx + dy * dy + dz * dz)
        return variance
    }

    /// Checks if the current motion exceeds a specified threshold.
    /// - Parameter threshold: The maximum allowable motion variance (default: 0.5)
    /// - Returns: True if motion exceeds threshold, false otherwise
    func isExcessiveMotion(threshold: Double = 0.5) -> Bool {
        return getCurrentMotionVariance() > threshold
    }

    /// Stops monitoring device motion and clears the baseline.
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        baselineAcceleration = nil
        isMonitoring = false
        print("🛑 Motion monitoring stopped")
    }

    /// Returns the current monitoring state.
    /// - Returns: True if actively monitoring, false otherwise
    func getMonitoringState() -> Bool {
        return isMonitoring
    }

    /// Returns the baseline acceleration if available.
    /// - Returns: The baseline CMAcceleration or nil if not set
    func getBaselineAcceleration() -> CMAcceleration? {
        return baselineAcceleration
    }

    /// Returns the current acceleration reading if available.
    /// - Returns: The current CMAcceleration or nil if not available
    func getCurrentAcceleration() -> CMAcceleration? {
        return motionManager.accelerometerData?.acceleration
    }
}

#else
// Stub implementation for platforms without CoreMotion (macOS, etc.)
/// Manages motion detection using CoreMotion to identify movement artifacts during measurement.
/// This is a stub implementation for platforms that don't support CoreMotion.
actor MotionManager {
    /// Starts monitoring device motion (stub implementation).
    func startMonitoring() {
        print("⚠️ Motion monitoring not available on this platform")
    }

    /// Returns current motion variance (always 0.0 on unsupported platforms).
    func getCurrentMotionVariance() -> Double {
        return 0.0
    }

    /// Checks if motion exceeds threshold (always false on unsupported platforms).
    func isExcessiveMotion(threshold: Double = 0.5) -> Bool {
        return false
    }

    /// Stops monitoring device motion (stub implementation).
    func stopMonitoring() {
        // No-op on platforms without CoreMotion
    }

    /// Returns the current monitoring state (always false on unsupported platforms).
    func getMonitoringState() -> Bool {
        return false
    }
}
#endif
