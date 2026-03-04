import Foundation
import AVFoundation
import CoreMedia
import Accelerate

#if os(iOS)
/// Manages camera capture for photoplethysmography (PPG) signal acquisition.
/// Captures 60fps video from the rear camera, extracts a 100×100 ROI from the center,
/// and streams mean Red/Blue channel values via AsyncStream.
actor CameraManager: NSObject, ObservableObject {

    // MARK: - Configuration Constants

    /// Video dimensions for capture
    private let videoWidth: Int = 1920
    private let videoHeight: Int = 1080

    /// Target frame rate (fps)
    private let targetFPS: Double = 60.0

    /// ROI dimensions (center crop)
    private let roiSize: Int = 100

    /// Torch brightness level (0.0 - 1.0)
    private let torchBrightness: Float = 0.1

    // MARK: - Camera Settings

    /// Exposure mode - locked for consistent illumination
    private let exposureMode: AVCaptureDevice.ExposureMode = .locked

    /// ISO range for exposure (lower ISO = less noise)
    private let minISO: Float = 50.0
    private let maxISO: Float = 100.0

    /// Exposure duration (1/100 second)
    private let exposureDuration: CMTime = CMTime(value: 1, timescale: 100)

    /// White balance temperature (Kelvin)
    private let whiteBalanceTemperature: Float = 5000.0

    /// White balance tint (green-magenta shift)
    private let whiteBalanceTint: Float = 0.0

    /// RGB gains for white balance
    private let redGain: Float = 1.5
    private let greenGain: Float = 1.0
    private let blueGain: Float = 1.8

    /// Focus mode - locked
    private let focusMode: AVCaptureDevice.FocusMode = .locked

    /// Lens position (0.0 - 1.0, where 1.0 is infinity focus)
    private let lensPosition: Float = 1.0

    // MARK: - Properties

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var captureDevice: AVCaptureDevice?

    private var continuation: AsyncStream<PPGSample>.Continuation?
    private var sampleStream: AsyncStream<PPGSample>!

    /// Indicates whether the capture session is currently running
    private(set) var isSessionRunning: Bool = false

    /// Current torch state
    private(set) var isTorchEnabled: Bool = false

    // MARK: - Initialization

    override init() {
        super.init()
        setupSampleStream()
    }

    /// Sets up the AsyncStream for PPG samples
    private func setupSampleStream() {
        sampleStream = AsyncStream { continuation in
            self.continuation = continuation

            // Handle stream termination
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.cleanup()
            }
        }
    }

    // MARK: - Public Methods

    /// Public accessor for the sample stream
    var samplePublisher: AsyncStream<PPGSample> {
        return sampleStream
    }

    /// Alias for compatibility (as specified in requirements)
    var sampleStream: AsyncStream<PPGSample> {
        return sampleStream
    }

    /// Sets up the camera session with locked settings for PPG capture.
    /// - Throws: CameraError if camera authorization fails or device not available
    func setupCamera() async throws {
        // Check camera authorization
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authStatus {
        case .authorized:
            break // Good to go
        case .notDetermined:
            // Request authorization
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                throw CameraError.authorizationDenied
            }
        case .denied, .restricted:
            throw CameraError.authorizationDenied
        @unknown default:
            throw CameraError.authorizationDenied
        }

        // Get the rear camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotAvailable
        }

        self.captureDevice = device

        // Create capture session
        let session = AVCaptureSession()
        session.sessionPreset = .high // We'll configure custom format below
        self.captureSession = session

        do {
            // Configure device with locked settings
            try configureDevice(device)

            // Create input
            let input = try AVCaptureDeviceInput(device: device)

            // Add input to session
            guard session.canAddInput(input) else {
                throw CameraError.configurationFailed
            }
            session.addInput(input)

            // Configure video output
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = false

            // Set up delegate on a separate queue
            let videoQueue = DispatchQueue(label: "com.spo2monitor.videoprocessing", qos: .userInteractive)
            output.setSampleBufferDelegate(self, queue: videoQueue)

            // Add output to session
            guard session.canAddOutput(output) else {
                throw CameraError.configurationFailed
            }
            session.addOutput(output)

            self.videoOutput = output

            // Configure connection for 60fps
            if let connection = output.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = false

                // Enable video stabilization for more stable ROI
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .standard
                }
            }

            print("📹 Camera configured successfully:")
            print("   - Resolution: \(videoWidth)×\(videoHeight)")
            print("   - Frame rate: \(targetFPS) fps")
            print("   - ROI: \(roiSize)×\(roiSize) center crop")
            print("   - Exposure: ISO \(minISO)-\(maxISO), \(exposureDuration.seconds)s")
            print("   - White Balance: \(whiteBalanceTemperature)K")
            print("   - Focus: locked at lens position \(lensPosition)")

        } catch {
            throw CameraError.configurationFailed
        }
    }

    /// Configures the capture device with locked settings for PPG capture.
    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()

        defer {
            device.unlockForConfiguration()
        }

        // Find the best format for 60fps at 1080p
        var targetFormat: AVCaptureDevice.Format?
        var targetFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            // Get format dimensions
            let formatDescription = format.formatDescription
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

            // Check if format matches our target resolution
            if dimensions.width == videoWidth && dimensions.height == videoHeight {
                // Check for frame rate range that includes 60fps
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= targetFPS && range.minFrameRate <= targetFPS {
                        targetFormat = format
                        targetFrameRateRange = range
                        break
                    }
                }
            }

            if targetFormat != nil {
                break
            }
        }

        // If exact match not found, use first format supporting 60fps
        if targetFormat == nil {
            for format in device.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= targetFPS {
                        targetFormat = format
                        targetFrameRateRange = range
                        break
                    }
                }
                if targetFormat != nil { break }
            }
        }

        // Apply format
        if let format = targetFormat {
            device.activeFormat = format
        }

        // Set frame rate
        if let range = targetFrameRateRange {
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(targetFPS))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(targetFPS))
        }

        // Lock exposure
        if device.isExposureModeSupported(exposureMode) {
            device.exposureMode = exposureMode

            // Set exposure duration and ISO
            if let minDuration = device.activeFormat.minExposureDuration,
               let maxDuration = device.activeFormat.maxExposureDuration {
                let clampedDuration = CMTimeClampToRange(exposureDuration, range: CMTimeRange(start: minDuration, end: maxDuration))

                // Clamp ISO to device's active format range
                let clampedISO = min(maxISO, max(minISO, device.activeFormat.maxISO))

                device.setExposureModeCustom(duration: clampedDuration, iso: clampedISO)
            }
        }

        // Lock white balance
        if device.isWhiteBalanceModeSupported(.locked) {
            device.whiteBalanceMode = .locked

            // Set temperature and tint
            if let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                temperature: whiteBalanceTemperature,
                tint: whiteBalanceTint
            ) {
                let rgbGains = device.deviceWhiteBalanceGains(for: temperatureAndTint)

                // Clamp gains to device limits
                var clampedGains = rgbGains
                if let maxGain = device.maxWhiteBalanceGain {
                    clampedGains.redGain = min(rgbGains.redGain, maxGain)
                    clampedGains.blueGain = min(rgbGains.blueGain, maxGain)
                    clampedGains.greenGain = min(rgbGains.greenGain, maxGain)
                }

                device.setWhiteBalanceModeLocked(with: clampedGains, completionHandler: nil)
            }
        }

        // Lock focus
        if device.isFocusModeSupported(focusMode) {
            device.focusMode = focusMode

            // Set lens position
            if device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: lensPosition, completionHandler: nil)
            }
        }

        // Configure torch (but don't enable it yet)
        if device.hasTorch && device.isTorchAvailable {
            if device.isTorchModeSupported(.on) {
                device.torchMode = .off
            }
        }
    }

    /// Starts the capture session.
    func startSession() async throws {
        guard let session = captureSession, !isSessionRunning else {
            return
        }

        await MainActor.run {
            session.startRunning()
        }

        // Wait for session to start and verify state
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01s
            if session.isRunning {
                break
            }
        }

        guard session.isRunning else {
            throw CameraError.configurationFailed
        }

        isSessionRunning = true
        print("🎬 Camera session started")
    }

    /// Stops the capture session.
    func stopSession() async throws {
        guard let session = captureSession, isSessionRunning else {
            return
        }

        await MainActor.run {
            session.stopRunning()
        }

        // Wait for session to stop and verify state
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01s
            if !session.isRunning {
                break
            }
        }

        isSessionRunning = session.isRunning
        print("🛑 Camera session stopped")

        // Turn off torch
        await setTorch(enabled: false)
    }

    /// Sets the torch on or off.
    /// - Parameter enabled: Whether to enable the torch
    func setTorch(enabled: Bool) async {
        guard let device = captureDevice, device.hasTorch else {
            return
        }

        do {
            try device.lockForConfiguration()

            if enabled && device.isTorchAvailable && device.isTorchModeSupported(.on) {
                // Try to set torch level
                if device.isTorchModeSupported(.on) {
                    do {
                        try device.setTorchModeOn(level: torchBrightness)
                        isTorchEnabled = true
                        print("🔦 Torch enabled at \(torchBrightness * 100)%")
                    } catch {
                        device.torchMode = .on
                        isTorchEnabled = true
                        print("🔦 Torch enabled (default level)")
                    }
                }
            } else {
                device.torchMode = .off
                isTorchEnabled = false
                print("🔦 Torch disabled")
            }

            device.unlockForConfiguration()
        } catch {
            print("⚠️ Failed to set torch: \(error.localizedDescription)")
        }
    }

    /// Cleans up resources
    private func cleanup() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        captureDevice = nil
        continuation = nil
        isSessionRunning = false
        isTorchEnabled = false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Extract ROI and calculate mean R/B values on the delegate queue
        let (meanRed, meanBlue) = extractROIMeanValues(from: pixelBuffer)

        // Get timestamp
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Create PPG sample
        let sample = PPGSample(red: meanRed, blue: meanBlue, timestamp: timestamp)

        // Emit to stream using proper actor isolation
        Task {
            await self.yieldSample(sample)
        }
    }

    /// Helper method to yield sample within actor isolation
    private func yieldSample(_ sample: PPGSample) {
        continuation?.yield(sample)
    }

    /// Extracts a 100×100 ROI from the center of the image and calculates mean R/B values.
    /// - Parameter pixelBuffer: The input pixel buffer
    /// - Returns: A tuple of (meanRed, meanBlue) values normalized to 0.0-1.0
    private func extractROIMeanValues(from pixelBuffer: CVPixelBuffer) -> (Double, Double) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard width >= roiSize && height >= roiSize else {
            return (0.0, 0.0)
        }

        // Calculate ROI origin (center crop)
        let xOrigin = (width - roiSize) / 2
        let yOrigin = (height - roiSize) / 2

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return (0.0, 0.0)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var totalRed: UInt64 = 0
        var totalBlue: UInt64 = 0
        var pixelCount: UInt64 = 0

        if pixelFormat == kCVPixelFormatType_32BGRA {
            // Process BGRA pixel data
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            for y in 0..<roiSize {
                let rowOffset = (yOrigin + y) * bytesPerRow + xOrigin * 4

                for x in 0..<roiSize {
                    let pixelOffset = rowOffset + x * 4

                    let blue = UInt64(buffer[pixelOffset])
                    let green = UInt64(buffer[pixelOffset + 1])
                    let red = UInt64(buffer[pixelOffset + 2])
                    // alpha = buffer[pixelOffset + 3]

                    totalBlue += blue
                    totalRed += red
                    pixelCount += 1
                }
            }
        } else if pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
                  pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
            // Process YUV 420 pixel data
            // For simplicity, we'll use the luma channel as a proxy
            // In production, you might want to do full YUV to RGB conversion
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            for y in 0..<roiSize {
                let rowOffset = (yOrigin + y) * bytesPerRow + xOrigin

                for x in 0..<roiSize {
                    let yValue = UInt64(buffer[rowOffset + x])
                    totalRed += yValue
                    totalBlue += yValue
                    pixelCount += 1
                }
            }
        }

        guard pixelCount > 0 else {
            return (0.0, 0.0)
        }

        let meanRed = Double(totalRed) / Double(pixelCount) / 255.0
        let meanBlue = Double(totalBlue) / Double(pixelCount) / 255.0

        return (meanRed, meanBlue)
    }
}

// MARK: - Camera Error

enum CameraError: LocalizedError {
    case authorizationDenied
    case deviceNotAvailable
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Camera access was denied. Please enable camera permissions in Settings."
        case .deviceNotAvailable:
            return "No camera device is available on this device."
        case .configurationFailed:
            return "Failed to configure the camera for PPG capture."
        }
    }
}

#else
// Stub implementation for macOS
/// Stub implementation for platforms without AVFoundation (macOS, etc.)
actor CameraManager {
    var isSessionRunning: Bool = false
    var isTorchEnabled: Bool = false

    func setupCamera() async throws {
        print("⚠️ CameraManager is iOS-only")
    }

    func startSession() async {
        print("⚠️ CameraManager is iOS-only")
    }

    func stopSession() async {
        print("⚠️ CameraManager is iOS-only")
    }

    func setTorch(enabled: Bool) async {
        print("⚠️ CameraManager is iOS-only")
    }

    var samplePublisher: AsyncStream<PPGSample> {
        return AsyncStream { _ in }
    }

    var sampleStream: AsyncStream<PPGSample> {
        return AsyncStream { _ in }
    }
}
#endif
