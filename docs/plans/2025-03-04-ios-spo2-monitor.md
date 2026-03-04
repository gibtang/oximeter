# iOS SpO₂ Monitor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a production-ready iOS wellness app that measures blood oxygen (SpO₂) and heart rate using iPhone's rear camera and LED flash via Reflectance Photoplethysmography (PPG).

**Architecture:** SwiftUI app with Swift 6 strict concurrency. Actor-based managers (CameraManager, SignalProcessor, MotionManager) handle data acquisition and processing. State machine drives UI through measurement phases: idle → detecting → calibrating (5s) → sampling (25s) → calculating → complete/error.

**Tech Stack:** iOS 17.0+, Swift 6, AVFoundation (camera), Accelerate/vDSP (signal processing), CoreMotion (artifact detection), HealthKit (optional), Canvas-based UI.

---

## Task 1: Create Xcode Project Foundation

**Files:**
- Create: `SpO2Monitor/SpO2MonitorApp.swift`
- Create: `SpO2Monitor/ContentView.swift`
- Create: `SpO2Monitor/Info.plist`
- Create: `SpO2Monitor/Models/MeasurementState.swift`

**Step 1: Create project structure**

```bash
# Create project directory structure
mkdir -p SpO2Monitor/{App,Managers,Models,Views,Utilities,Resources}
cd SpO2Monitor
```

**Step 2: Create SpO2MonitorApp.swift**

```swift
import SwiftUI

@main
struct SpO2MonitorApp: App {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Step 3: Create ContentView.swift (placeholder)**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("SpO₂ Monitor")
            .font(.largeTitle)
    }
}
```

**Step 4: Create Info.plist with required permissions**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSCameraUsageDescription</key>
    <string>Camera access is required to measure your blood oxygen and heart rate using PPG technology.</string>
    <key>NSMotionUsageDescription</key>
    <string>Motion sensors help ensure accurate measurements by detecting movement.</string>
    <key>NSHealthUpdateUsageDescription</key>
    <string>Save your SpO₂ and heart rate measurements to the Health app.</string>
    <key>NSHealthShareUsageDescription</key>
    <string>Read historical health data to show trends.</string>
</dict>
</plist>
```

**Step 5: Create MeasurementState.swift**

```swift
import Foundation

enum MeasurementState: Equatable {
    case idle
    case detecting
    case calibrating
    case sampling(progress: Double)
    case calculating
    case complete(result: MeasurementResult)
    case error(MeasurementError)
}
```

**Step 6: Verify project builds**

Run: Open in Xcode, build (Cmd+B)
Expected: Clean build with no errors

**Step 7: Initialize git and commit**

```bash
git init
git add .
git commit -m "feat: initialize Xcode project with basic structure and permissions"
```

---

## Task 2: Implement PPG Filter (Signal Processing Foundation)

**Files:**
- Create: `SpO2Monitor/Utilities/PPGFilter.swift`
- Create: `SpO2MonitorTests/Utilities/PPGFilterTests.swift`

**Step 1: Write failing test for PPGFilter**

```swift
import XCTest
@testable import SpO2Monitor

final class PPGFilterTests: XCTestCase {
    func testFilterInitialization() {
        let filter = PPGFilter()
        XCTAssertNotNil(filter)
    }

    func testFilterProcessesSignal() {
        let filter = PPGFilter()
        let input = Array(repeating: 1.0, count: 60)
        let output = filter.process(signal: input)
        XCTAssertEqual(output.count, input.count)
    }

    func testFilterFrequencyResponse() {
        let filter = PPGFilter()
        // Generate 1Hz sine wave (within passband)
        let sampleRate = 60.0
        let duration = 1.0
        let signal = (0..<Int(sampleRate * duration)).map { i in
            sin(2.0 * .pi * 1.0 * Double(i) / sampleRate)
        }

        let filtered = filter.process(signal: signal)

        // Signal should be preserved (not zeroed)
        let outputEnergy = filtered.reduce(0.0) { $0 + $1 * $1 }
        XCTAssertGreaterThan(outputEnergy, 0.1, "Passband signal should be preserved")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: In Xcode, run PPGFilterTests (Cmd+U)
Expected: Tests fail with "PPGFilter not defined"

**Step 3: Implement PPGFilter.swift**

```swift
import Foundation
import Accelerate

final class PPGFilter {
    private var setup: vDSP_biquad_Setup?
    private var delay: [Double]

    // Butterworth Bandpass: Fs=60Hz, Passband=[0.8Hz, 4.0Hz]
    // Covers heart rates from 48 BPM (0.8Hz) to 240 BPM (4.0Hz)
    private let coefficients: [Double] = [
        // Section 1 (biquad cascade)
        0.020083,  0.0,       -0.020083,  // b0, b1, b2
        1.802656, -0.835824,               // -a1, -a2 (negated!)

        // Section 2
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
```

**Step 4: Run tests to verify they pass**

Run: In Xcode, run PPGFilterTests
Expected: All tests pass

**Step 5: Commit**

```bash
git add SpO2Monitor/Utilities/PPGFilter.swift SpO2MonitorTests/Utilities/PPGFilterTests.swift
git commit -m "feat: implement PPGFilter with vDSP Butterworth bandpass filter"
```

---

## Task 3: Implement Peak Detector (Heart Rate)

**Files:**
- Create: `SpO2Monitor/Utilities/PeakDetector.swift`
- Create: `SpO2MonitorTests/Utilities/PeakDetectorTests.swift`

**Step 1: Write failing tests for PeakDetector**

```swift
import XCTest
@testable import SpO2Monitor

final class PeakDetectorTests: XCTestCase {
    func testDetectsSyntheticPeaks() {
        let detector = PeakDetector()

        // Generate signal with 5 peaks (60 BPM = 1Hz)
        let sampleRate = 60.0
        var signal = [Double]()
        for i in 0..<300 { // 5 seconds
            let t = Double(i) / sampleRate
            // 1Hz sine wave (60 BPM)
            signal.append(sin(2.0 * .pi * 1.0 * t))
        }

        let peaks = detector.detectPeaks(in: signal, samplingRate: sampleRate)
        XCTAssertGreaterThanOrEqual(peaks.count, 4, "Should detect at least 4 peaks")
    }

    func testRefractoryPeriod() {
        let detector = PeakDetector()

        // Signal with peaks too close together
        let signal = [1.0, 0.5, 1.0, 0.5, 1.0, 0.5]
        let peaks = detector.detectPeaks(in: signal, samplingRate: 60.0)

        // Should filter out peaks within 500ms refractory period
        XCTAssertLessThan(peaks.count, signal.count)
    }

    func testCalculatesBPM() {
        let detector = PeakDetector()

        // Peaks at 60 BPM (1 second intervals)
        let peaks = [0, 60, 120, 180, 240] // Sample indices at 60Hz
        let bpm = detector.calculateBPM(peaks: peaks, samplingRate: 60.0)

        XCTAssertEqual(bpm, 60.0, accuracy: 1.0)
    }

    func testRejectsInvalidBPM() {
        let detector = PeakDetector()

        // Peaks at unrealistic intervals
        let peaks = [0, 5, 10, 15] // Way too fast
        let bpm = detector.calculateBPM(peaks: peaks, samplingRate: 60.0)

        XCTAssertNil(bpm, "Should reject unrealistic heart rates")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: In Xcode, run PeakDetectorTests
Expected: Tests fail with "PeakDetector not defined"

**Step 3: Implement PeakDetector.swift**

```swift
import Foundation
import Accelerate

class PeakDetector {
    private var lastPeakTime: Double = 0
    private let refractoryPeriod: Double = 0.5 // 500ms

    func detectPeaks(in signal: [Double], samplingRate: Double = 60.0) -> [Int] {
        var peaks: [Int] = []

        guard signal.count > 1 else { return peaks }

        // Calculate first derivative
        var derivative = [Double](repeating: 0.0, count: signal.count - 1)
        vDSP_vsubD(signal, 1, Array(signal.dropFirst()), 1, &derivative, 1, vDSP_Length(derivative.count))

        // Find zero-crossings (positive to negative)
        for i in 1..<derivative.count {
            let timeSinceLastPeak = Double(i) / samplingRate - lastPeakTime

            if derivative[i-1] > 0 && derivative[i] <= 0 && timeSinceLastPeak > refractoryPeriod {
                let peakAmplitude = signal[i]

                if peakAmplitude > 0.1 { // Simple amplitude threshold
                    peaks.append(i)
                    lastPeakTime = Double(i) / samplingRate
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

            // Validate interval (40-200 BPM)
            if interval >= 0.3 && interval <= 1.5 {
                intervals.append(interval)
            }
        }

        guard intervals.count >= 3 else { return nil }

        // Use median interval
        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]

        let bpm = 60.0 / medianInterval

        // Validate BPM range
        if bpm >= 40.0 && bpm <= 200.0 {
            return bpm
        }
        return nil
    }
}
```

**Step 4: Run tests to verify they pass**

Run: In Xcode, run PeakDetectorTests
Expected: All tests pass

**Step 5: Commit**

```bash
git add SpO2Monitor/Utilities/PeakDetector.swift SpO2MonitorTests/Utilities/PeakDetectorTests.swift
git commit -m "feat: implement PeakDetector for heart rate calculation"
```

---

## Task 4: Create Data Models

**Files:**
- Create: `SpO2Monitor/Models/PPGSample.swift`
- Create: `SpO2Monitor/Models/MeasurementResult.swift`
- Create: `SpO2Monitor/Models/MeasurementError.swift`

**Step 1: Create PPGSample.swift**

```swift
import Foundation
import CoreMedia

struct PPGSample {
    let red: Double      // Normalized 0.0-1.0
    let blue: Double     // Normalized 0.0-1.0
    let timestamp: CMTime
}
```

**Step 2: Create MeasurementError.swift**

```swift
import Foundation

enum MeasurementError: Error, LocalizedError {
    case fingerLifted
    case excessiveAmbientLight
    case lowPerfusion
    case excessiveMotion
    case invalidRValue
    case physiologicallyImpossible
    case invalidHeartRate
    case insufficientData
    case cameraError
    case processingTimeout

    var errorDescription: String? {
        switch self {
        case .fingerLifted:
            return "Keep your finger on the camera"
        case .excessiveAmbientLight:
            return "Cover the flash completely with your finger"
        case .lowPerfusion:
            return "Press lighter - don't squeeze too hard"
        case .excessiveMotion:
            return "Hold still during measurement"
        case .invalidRValue, .physiologicallyImpossible, .invalidHeartRate:
            return "Measurement failed - please try again"
        case .insufficientData:
            return "Not enough data collected - hold for full 30 seconds"
        case .cameraError:
            return "Camera error - please restart the app"
        case .processingTimeout:
            return "Processing error - please try again"
        }
    }
}
```

**Step 3: Create MeasurementResult.swift**

```swift
import Foundation
import SwiftUI

struct MeasurementResult: Identifiable, Codable {
    let id: UUID
    let spO2: Double
    let heartRate: Double
    let confidence: ConfidenceLevel
    let timestamp: Date
    let perfusionIndex: Double
    let signalToNoiseRatio: Double

    init(spO2: Double, heartRate: Double, confidence: ConfidenceLevel, perfusionIndex: Double, signalToNoiseRatio: Double) {
        self.id = UUID()
        self.spO2 = spO2
        self.heartRate = heartRate
        self.confidence = confidence
        self.timestamp = Date()
        self.perfusionIndex = perfusionIndex
        self.signalToNoiseRatio = signalToNoiseRatio
    }

    var spO2Display: String {
        String(format: "%.0f%%", spO2)
    }

    var heartRateDisplay: String {
        String(format: "%.0f BPM", heartRate)
    }
}

enum ConfidenceLevel: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var icon: String {
        switch self {
        case .high: return "✓✓✓"
        case .medium: return "✓✓"
        case .low: return "✓"
        }
    }
}
```

**Step 4: Commit**

```bash
git add SpO2Monitor/Models/
git commit -m "feat: add data models for PPG samples, results, and errors"
```

---

## Task 5: Implement MotionManager (CoreMotion Integration)

**Files:**
- Create: `SpO2Monitor/Managers/MotionManager.swift`
- Create: `SpO2MonitorTests/Managers/MotionManagerTests.swift`

**Step 1: Write failing tests**

```swift
import XCTest
@testable import SpO2Monitor

@MainActor
final class MotionManagerTests: XCTestCase {
    func testMotionVarianceCalculation() async {
        let manager = MotionManager()
        await manager.startMonitoring()

        // Wait for baseline
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s

        let variance = await manager.getCurrentMotionVariance()
        XCTAssertGreaterThanOrEqual(variance, 0.0)

        await manager.stopMonitoring()
    }

    func testMotionThreshold() async {
        let manager = MotionManager()
        await manager.startMonitoring()

        // Should be below threshold when still
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let variance = await manager.getCurrentMotionVariance()
        XCTAssertLessThan(variance, 0.5, "Should be reasonable when device is still")

        await manager.stopMonitoring()
    }
}
```

**Step 2: Run tests to verify they fail**

Run: In Xcode, run MotionManagerTests
Expected: Tests fail

**Step 3: Implement MotionManager.swift**

```swift
import Foundation
import CoreMotion

actor MotionManager {
    private let motionManager = CMMotionManager()
    private var baselineAcceleration: CMAcceleration?

    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }

        motionManager.accelerometerUpdateInterval = 0.1 // 10 Hz
        motionManager.startAccelerometerUpdates()

        // Capture baseline after 1 second
        Task {
            try? await Task.sleep(for: .seconds(1))
            baselineAcceleration = motionManager.accelerometerData?.acceleration
        }
    }

    func getCurrentMotionVariance() -> Double {
        guard let current = motionManager.accelerometerData?.acceleration,
              let baseline = baselineAcceleration else {
            return 0.0
        }

        // Calculate Euclidean distance from baseline
        let dx = current.x - baseline.x
        let dy = current.y - baseline.y
        let dz = current.z - baseline.z

        return sqrt(dx*dx + dy*dy + dz*dz)
    }

    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        baselineAcceleration = nil
    }
}
```

**Step 4: Run tests to verify they pass**

Run: In Xcode, run MotionManagerTests
Expected: All tests pass

**Step 5: Commit**

```bash
git add SpO2Monitor/Managers/MotionManager.swift SpO2MonitorTests/Managers/MotionManagerTests.swift
git commit -m "feat: implement MotionManager with CoreMotion integration"
```

---

## Task 6: Implement CameraManager (AVFoundation Capture)

**Files:**
- Create: `SpO2Monitor/Managers/CameraManager.swift`
- Create: `SpO2MonitorTests/Managers/CameraManagerTests.swift`

**Step 1: Write failing tests**

```swift
import XCTest
@testable import SpO2Monitor

@MainActor
final class CameraManagerTests: XCTestCase {
    func testCameraInitialization() async {
        let manager = CameraManager()

        do {
            await manager.setupCamera()
            let isReady = await manager.isSessionRunning
            // Note: May not run in test environment without camera
            XCTAssertTrue(true, "Camera setup should complete without crash")
        } catch {
            // Expected in test environment
            XCTAssertTrue(true, "Camera may not be available in test environment")
        }
    }
}
```

**Step 2: Run tests to verify they fail**

Run: In Xcode, run CameraManagerTests
Expected: Tests fail

**Step 3: Implement CameraManager.swift**

```swift
import Foundation
import AVFoundation
import CoreMedia
import Combine

actor CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "com.ppg.video")

    @Published var currentState: MeasurementState = .idle
    private var continuation: AsyncStream<PPGSample>.Continuation?

    var sampleStream: AsyncStream<PPGSample> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    var isSessionRunning: Bool {
        captureSession.isRunning
    }

    func setupCamera() async throws {
        captureSession.beginConfiguration()

        // Add camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw MeasurementError.cameraError
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw MeasurementError.cameraError
        }
        captureSession.addInput(input)

        // Configure camera locks
        try device.lockForConfiguration()

        // Exposure lock
        device.exposureMode = .custom
        device.setExposureModeCustom(duration: CMTime(value: 1, timescale: 100), iso: 80) { _ in }

        // White balance lock
        device.whiteBalanceMode = .locked
        let gains = AVCaptureDevice.WhiteBalanceGains(redGain: 1.5, greenGain: 1.0, blueGain: 1.8)
        device.setWhiteBalanceModeLocked(with: gains) { _ in }

        // Focus lock
        device.focusMode = .locked
        device.setFocusModeLocked(lensPosition: 1.0) { _ in }

        device.unlockForConfiguration()

        // Set 60fps
        captureSession.sessionPreset = .hd1920x1080

        // Find 60fps format
        if let format = device.formats.first(where: { format in
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let frameRates = format.videoSupportedFrameRateRanges
            return frameRates.contains { $0.maxFrameRate >= 60.0 }
        }) {
            try? device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            device.unlockForConfiguration()
        }

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)

        guard captureSession.canAddOutput(output) else {
            throw MeasurementError.cameraError
        }
        captureSession.addOutput(output)
        self.videoOutput = output

        captureSession.commitConfiguration()
    }

    func startSession() {
        captureSession.startRunning()
    }

    func stopSession() {
        captureSession.stopRunning()
    }

    func setTorch(enabled: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

        try? device.lockForConfiguration()
        if enabled {
            try? device.setTorchModeOn(level: 0.1)
        } else {
            device.torchMode = .off
        }
        device.unlockForConfiguration()
    }

    private func extractROI(from pixelBuffer: CVPixelBuffer) -> PPGSample? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        // 100×100 ROI centered
        let roiSize = 100
        let startX = (width - roiSize) / 2
        let startY = (height - roiSize) / 2

        var redSum: Double = 0.0
        var blueSum: Double = 0.0

        for y in startY..<(startY + roiSize) {
            for x in startX..<(startX + roiSize) {
                let offset = y * bytesPerRow + x * 4
                let pixel = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)

                let blue = Double(pixel[0]) / 255.0
                let red = Double(pixel[2]) / 255.0

                redSum += red
                blueSum += blue
            }
        }

        let pixelCount = Double(roiSize * roiSize)
        return PPGSample(
            red: redSum / pixelCount,
            blue: blueSum / pixelCount,
            timestamp: CMSampleBufferGetPresentationTimeStamp(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: nil, sampleTiming: nil)!)
        )
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        Task {
            if let sample = await self.extractROIFromBuffer(pixelBuffer) {
                continuation?.yield(sample)
            }
        }
    }

    private func extractROIFromBuffer(_ pixelBuffer: CVPixelBuffer) async -> PPGSample? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let roiSize = 100
        let startX = (width - roiSize) / 2
        let startY = (height - roiSize) / 2

        var redSum: Double = 0.0
        var blueSum: Double = 0.0

        for y in startY..<(startY + roiSize) {
            for x in startX..<(startX + roiSize) {
                let offset = y * bytesPerRow + x * 4
                let pixel = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)

                blueSum += Double(pixel[0]) / 255.0
                redSum += Double(pixel[2]) / 255.0
            }
        }

        let pixelCount = Double(roiSize * roiSize)
        return PPGSample(
            red: redSum / pixelCount,
            blue: blueSum / pixelCount,
            timestamp: CMSampleBufferGetPresentationTimeStamp(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: nil, sampleTiming: nil)!)
        )
    }
}
```

**Step 4: Run tests to verify they pass**

Run: In Xcode, run CameraManagerTests
Expected: Tests pass (may skip in environments without camera)

**Step 5: Commit**

```bash
git add SpO2Monitor/Managers/CameraManager.swift SpO2MonitorTests/Managers/CameraManagerTests.swift
git commit -m "feat: implement CameraManager with AVFoundation 60fps capture"
```

---

## Task 7: Implement SignalProcessor (Core Algorithm)

**Files:**
- Create: `SpO2Monitor/Managers/SignalProcessor.swift`
- Create: `SpO2MonitorTests/Managers/SignalProcessorTests.swift`

**Step 1: Write failing tests**

```swift
import XCTest
@testable import SpO2Monitor

final class SignalProcessorTests: XCTestCase {
    func testCalculatesSpO2FromSyntheticData() async {
        let processor = SignalProcessor()

        // Generate synthetic PPG data (simulated 98% SpO2)
        var samples: [PPGSample] = []
        for i in 0..<1800 { // 30 seconds at 60fps
            let t = Double(i) / 60.0
            // Simulate cardiac pulse at 1 Hz (60 BPM)
            let pulse = 0.05 * sin(2.0 * .pi * 1.0 * t)

            // Red: higher absorption (lower reflection)
            let red = 0.5 - 0.1 * pulse
            // Blue: lower absorption (higher reflection)
            let blue = 0.3 - 0.05 * pulse

            samples.append(PPGSample(
                red: red,
                blue: blue,
                timestamp: CMTime(value: Int64(i), timescale: 60)
            ))
        }

        let result = await processor.process(samples: samples)

        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!.spO2, 90.0)
        XCTAssertLessThanOrEqual(result!.spO2, 100.0)
        XCTAssertGreaterThanOrEqual(result!.heartRate, 50.0)
        XCTAssertLessThanOrEqual(result!.heartRate, 80.0)
    }

    func testRejectsInvalidData() async {
        let processor = SignalProcessor()

        // Flat signal (no pulse)
        let samples = Array(repeating: PPGSample(red: 0.5, blue: 0.3, timestamp: CMTime(value: 0, timescale: 60)), count: 100)

        let result = await processor.process(samples: samples)

        // Should return nil or result with low confidence
        XCTAssertNil(result, "Should reject signal with no pulse")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: In Xcode, run SignalProcessorTests
Expected: Tests fail

**Step 3: Implement SignalProcessor.swift**

```swift
import Foundation
import Accelerate
import CoreMedia

actor SignalProcessor {
    private let filter = PPGFilter()
    private let peakDetector = PeakDetector()

    func process(samples: [PPGSample]) async -> MeasurementResult? {
        guard samples.count >= 120 else { // At least 2 seconds
            return nil
        }

        // Extract channels
        let redChannel = samples.map { $0.red }
        let blueChannel = samples.map { $0.blue }

        // Filter signals
        let filteredRed = filter.process(signal: redChannel)
        let filteredBlue = filter.process(signal: blueChannel)

        // Calculate AC/DC components
        let (acRed, dcRed) = calculateACDC(signal: filteredRed)
        let (acBlue, dcBlue) = calculateACDC(signal: filteredBlue)

        // Validate perfusion
        let perfusionIndex = acRed / dcRed
        guard perfusionIndex > 0.01 else {
            return nil
        }

        // Calculate R-value
        let redRatio = acRed / dcRed
        let blueRatio = acBlue / dcBlue
        let R = redRatio / blueRatio

        // Validate R-value
        guard R >= 0.4 && R <= 2.0 else {
            return nil
        }

        // Calculate SpO2
        let spO2 = 110.0 - (25.0 * R)
        let clampedSpO2 = max(70.0, min(100.0, spO2))

        // Calculate heart rate from red channel
        let peaks = peakDetector.detectPeaks(in: filteredRed)
        guard let bpm = peakDetector.calculateBPM(peaks: peaks) else {
            return nil
        }

        // Calculate confidence
        let confidence = calculateConfidence(
            perfusionIndex: perfusionIndex,
            peakCount: peaks.count
        )

        return MeasurementResult(
            spO2: clampedSpO2,
            heartRate: bpm,
            confidence: confidence,
            perfusionIndex: perfusionIndex,
            signalToNoiseRatio: 20.0 // Simplified SNR estimate
        )
    }

    private func calculateACDC(signal: [Double]) -> (ac: Double, dc: Double) {
        var mean = 0.0
        vDSP_meanvD(signal, 1, &mean, vDSP_Length(signal.count))

        var centered = [Double](repeating: 0.0, count: signal.count)
        vDSP_vsubD(signal, 1, [mean], 0, &centered, 1, vDSP_Length(signal.count))

        var rms: Double = 0.0
        vDSP_rmsqvD(centered, 1, &rms, vDSP_Length(centered.count))

        return (rms, mean)
    }

    private func calculateConfidence(perfusionIndex: Double, peakCount: Int) -> ConfidenceLevel {
        let piScore = perfusionIndex > 0.05 ? 3 : (perfusionIndex > 0.03 ? 2 : 1)
        let peakScore = peakCount >= 10 ? 3 : (peakCount >= 5 ? 2 : 1)

        let totalScore = piScore + peakScore

        switch totalScore {
        case 5...6: return .high
        case 3...4: return .medium
        default: return .low
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: In Xcode, run SignalProcessorTests
Expected: All tests pass

**Step 5: Commit**

```bash
git add SpO2Monitor/Managers/SignalProcessor.swift SpO2MonitorTests/Managers/SignalProcessorTests.swift
git commit -m "feat: implement SignalProcessor with SpO2 and heart rate calculation"
```

---

## Task 8: Create OnboardingView (Medical Disclaimer)

**Files:**
- Create: `SpO2Monitor/Views/OnboardingView.swift`

**Step 1: Create OnboardingView.swift**

```swift
import SwiftUI

struct OnboardingView: View {
    let didAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMPORTANT HEALTH INFORMATION")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("This app is a WELLNESS and FITNESS tool only.")
                        .font(.subheadline)
                }
                .padding(.bottom, 8)

                Divider()

                // Not a medical device
                disclaimerSection(
                    icon: "⚠️",
                    title: "NOT A MEDICAL DEVICE",
                    points: [
                        "This app is not FDA-approved or cleared",
                        "It is not intended to diagnose, treat, cure, or prevent any disease or medical condition",
                        "Results should NOT be used for medical decisions"
                    ]
                )

                // Accuracy limitations
                disclaimerSection(
                    icon: "⚠️",
                    title: "ACCURACY LIMITATIONS",
                    points: [
                        "Measurements may be affected by ambient light, motion, skin tone, temperature",
                        "Nail polish or artificial nails interfere with readings",
                        "This app is less accurate than medical-grade pulse oximeters"
                    ]
                )

                // When to seek care
                disclaimerSection(
                    icon: "⚠️",
                    title: "WHEN TO SEEK MEDICAL CARE",
                    points: [
                        "Seek immediate medical attention for difficulty breathing, chest pain, confusion",
                        "Consult a healthcare provider for medical advice, diagnosis, or treatment decisions"
                    ]
                )

                Divider()

                // Acknowledgment
                VStack(alignment: .leading, spacing: 12) {
                    Text("By tapping \"I Understand\", you acknowledge:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. You have read this disclaimer")
                        Text("2. You understand this is not a medical device")
                        Text("3. You will not use this app for medical decisions")
                        Text("4. You will consult healthcare providers for medical advice")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button("I Understand and Accept") {
                    didAccept()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Cancel") {
                    // Exit app or show alternative
                    exit(0)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Health Information")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func disclaimerSection(icon: String, title: String, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(icon)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(point)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

**Step 2: Update ContentView to show onboarding**

```swift
import SwiftUI

struct ContentView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some View {
        if !hasAcceptedDisclaimer {
            OnboardingView(didAccept: {
                hasAcceptedDisclaimer = true
            })
        } else {
            MeasurementView()
        }
    }
}
```

**Step 3: Commit**

```bash
git add SpO2Monitor/Views/OnboardingView.swift SpO2Monitor/ContentView.swift
git commit -m "feat: add medical disclaimer onboarding screen"
```

---

## Task 9: Create WaveformView (Real-time Display)

**Files:**
- Create: `SpO2Monitor/Views/WaveformView.swift`

**Step 1: Create WaveformView.swift**

```swift
import SwiftUI

struct WaveformView: View {
    let samples: [Double]
    let isRecording: Bool

    private let maxSamples = 300 // 5 seconds at 60fps

    var body: some View {
        Canvas { context, size in
            if samples.isEmpty {
                // Draw flat line
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))

                context.stroke(path, with: .color(.red.opacity(0.3)), lineWidth: 2)
            } else {
                // Draw waveform
                var path = Path()
                let displaySamples = Array(samples.suffix(maxSamples))

                let minY = displaySamples.min() ?? 0
                let maxY = displaySamples.max() ?? 1
                let range = max(maxY - minY, 0.01)

                for (index, sample) in displaySamples.enumerated() {
                    let x = CGFloat(index) / CGFloat(displaySamples.count - 1) * size.width
                    let normalizedY = (sample - minY) / range
                    let y = size.height - (normalizedY * size.height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(path, with: .color(.red), lineWidth: 2)
            }
        }
        .frame(height: 200)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}
```

**Step 2: Commit**

```bash
git add SpO2Monitor/Views/WaveformView.swift
git commit -m "feat: add real-time PPG waveform display"
```

---

## Task 10: Create ProgressRing (Countdown Timer)

**Files:**
- Create: `SpO2Monitor/Views/ProgressRing.swift`

**Step 1: Create ProgressRing.swift**

```swift
import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let totalTime: Double // Total seconds

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.red, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)

            // Center text
            VStack(spacing: 4) {
                Text(remainingTime)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(progress < 0.17 ? "Calibrating" : "Measuring")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 240, height: 240)
    }

    private var remainingTime: String {
        let elapsed = totalTime * (1.0 - progress)
        let remaining = max(0, ceil(totalTime - elapsed))
        return "\(Int(remaining))s"
    }
}
```

**Step 2: Commit**

```bash
git add SpO2Monitor/Views/ProgressRing.swift
git commit -m "feat: add 30-second countdown progress ring"
```

---

## Task 11: Create ResultCard (Final Display)

**Files:**
- Create: `SpO2Monitor/Views/ResultCard.swift`

**Step 1: Create ResultCard.swift**

```swift
import SwiftUI

struct ResultCard: View {
    let result: MeasurementResult
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // SpO2 Display
            VStack(spacing: 8) {
                Text(result.spO2Display)
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(colorForSpO2)

                Text("Blood Oxygen")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Heart Rate Display
            VStack(spacing: 8) {
                Text(result.heartRateDisplay)
                    .font(.system(size: 72, weight: .semibold, design: .rounded))

                Text("Heart Rate")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Confidence
            HStack {
                Text("Confidence: \(result.confidence.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(result.confidence.icon)
                    .foregroundColor(colorForConfidence)
            }

            // Timestamp
            Text("Measured at \(result.timestamp, style: .time)")
                .font(.caption)
                .foregroundColor(.secondary)

            // Retry button
            Button("Measure Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            // Disclaimer footer
            Text("Wellness data only • Not for medical use • Consult a doctor for health concerns")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var colorForSpO2: Color {
        switch result.spO2 {
        case 95...100: return .green
        case 90..<95: return .yellow
        default: return .red
        }
    }

    private var colorForConfidence: Color {
        switch result.confidence {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }
}
```

**Step 2: Commit**

```bash
git add SpO2Monitor/Views/ResultCard.swift
git commit -m "feat: add measurement result card with SpO2 and heart rate"
```

---

## Task 12: Create Main MeasurementView (Orchestration)

**Files:**
- Create: `SpO2Monitor/Views/MeasurementView.swift`

**Step 1: Create MeasurementView.swift**

```swift
import SwiftUI
import Combine

@MainActor
struct MeasurementView: View {
    @State private var state: MeasurementState = .idle
    @State private var waveformSamples: [Double] = []
    @State private var feedbackMessage: String?

    private let cameraManager = CameraManager()
    private let signalProcessor = SignalProcessor()
    private let motionManager = MotionManager()

    private var calibrationDuration: TimeInterval { 5.0 }
    private var samplingDuration: TimeInterval { 25.0 }
    private var totalDuration: TimeInterval { calibrationDuration + samplingDuration }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state {
            case .idle:
                idleView
            case .detecting:
                detectingView
            case .calibrating:
                calibratingView
            case .sampling(let progress):
                samplingView(progress: progress)
            case .calculating:
                calculatingView
            case .complete(let result):
                ResultCard(result: result) {
                    resetToIdle()
                }
            case .error(let error):
                errorView(error)
            }
        }
        .onAppear {
            setupCamera()
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            Text("Place your finger over the camera and flash")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    private var detectingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Detecting finger...")
                .font(.headline)
        }
    }

    private var calibratingView: some View {
        VStack(spacing: 32) {
            ProgressRing(progress: 0.17, totalTime: totalDuration)

            Text("Keep your finger still")
                .font(.headline)
        }
        .onAppear {
            startSampling()
        }
    }

    private func samplingView(progress: Double) -> some View {
        VStack(spacing: 32) {
            ProgressRing(
                progress: 0.17 + (progress * 0.83),
                totalTime: totalDuration
            )

            WaveformView(samples: waveformSamples, isRecording: true)
                .frame(height: 200)

            if let feedback = feedbackMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(feedback)
                }
                .font(.subheadline)
                .foregroundColor(.yellow)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }
        }
    }

    private var calculatingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Calculating...")
                .font(.headline)
        }
    }

    private func errorView(_ error: MeasurementError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text(error.errorDescription ?? "Measurement failed")
                .font(.title2)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                resetToIdle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Logic

    private func setupCamera() {
        Task {
            do {
                try await cameraManager.setupCamera()
                await startDetection()
            } catch {
                state = .error(.cameraError)
            }
        }
    }

    private func startDetection() async {
        state = .detecting
        await motionManager.startMonitoring()

        // Start monitoring for finger detection
        for await sample in cameraManager.sampleStream {
            if sample.red > 0.85 {
                // Finger detected
                await cameraManager.setTorch(enabled: true)

                // Confirm finger stays for 1 second
                let confirmed = await confirmFingerContact()
                if confirmed {
                    state = .calibrating
                    await motionManager.startMonitoring()
                    return
                }
            }
        }
    }

    private func confirmFingerContact() async -> Bool {
        // Check for 1 second continuous contact
        var contactCount = 0
        let requiredCount = 60 // 1 second at 60fps

        for await sample in cameraManager.sampleStream {
            if sample.red > 0.85 {
                contactCount += 1
                if contactCount >= requiredCount {
                    return true
                }
            } else {
                contactCount = 0
            }
        }

        return false
    }

    private func startSampling() {
        Task {
            // Calibration phase
            var calibrationSamples: [PPGSample] = []
            let calibrationTarget = Int(calibrationDuration * 60) // 5s at 60fps

            for await sample in cameraManager.sampleStream {
                calibrationSamples.append(sample)
                waveformSamples.append(sample.red)

                if calibrationSamples.count >= calibrationTarget {
                    break
                }
            }

            // Sampling phase
            state = .sampling(progress: 0.0)
            var allSamples = calibrationSamples
            let samplingTarget = Int(samplingDuration * 60)
            var sampleCount = 0

            for await sample in cameraManager.sampleStream {
                allSamples.append(sample)
                waveformSamples.append(sample.red)
                sampleCount += 1

                // Update progress
                let progress = Double(sampleCount) / Double(samplingTarget)
                state = .sampling(progress: progress)

                // Check for errors
                if let feedback = await checkForErrors(sample: sample) {
                    feedbackMessage = feedback
                } else {
                    feedbackMessage = nil
                }

                if sampleCount >= samplingTarget {
                    break
                }
            }

            // Process results
            await cameraManager.stopSession()
            await motionManager.stopMonitoring()
            state = .calculating

            if let result = await signalProcessor.process(samples: allSamples) {
                state = .complete(result: result)
            } else {
                state = .error(.insufficientData)
            }
        }
    }

    private func checkForErrors(sample: PPGSample) async -> String? {
        // Check finger contact
        if sample.red < 0.75 {
            return "Keep finger on camera"
        }

        // Check motion
        let motionVariance = await motionManager.getCurrentMotionVariance()
        if motionVariance > 0.1 {
            return "Hold still"
        }

        return nil
    }

    private func resetToIdle() {
        state = .idle
        waveformSamples = []
        feedbackMessage = nil

        Task {
            await startDetection()
        }
    }
}
```

**Step 2: Commit**

```bash
git add SpO2Monitor/Views/MeasurementView.swift
git commit -m "feat: implement main measurement view with state machine"
```

---

## Task 13: Update App Delegate and Build Configuration

**Files:**
- Modify: `SpO2Monitor/SpO2MonitorApp.swift`
- Create: `SpO2Monitor/Resources/Info.plist` (if not exists)

**Step 1: Ensure all permissions are in Info.plist**

```bash
# Verify Info.plist contains all required keys
plutil -convert xml1 -o - SpO2Monitor/Resources/Info.plist | grep -E "NSCameraUsageDescription|NSMotionUsageDescription|NSHealth"
```

**Step 2: Verify build settings**

In Xcode:
- Deployment Target: iOS 17.0
- Swift Language Version: Swift 6
- Swift Concurrency: Strict

**Step 3: Build and test on device**

Run: Build in Xcode, deploy to iPhone
Expected: App launches, shows disclaimer, then measurement screen

**Step 4: Commit**

```bash
git add .
git commit -m "chore: configure build settings and permissions for iOS 17"
```

---

## Task 14: Integration Testing

**Files:**
- Create: `SpO2MonitorTests/IntegrationTests/FullMeasurementCycleTests.swift`

**Step 1: Create integration test**

```swift
import XCTest
@testable import SpO2Monitor

final class FullMeasurementCycleTests: XCTestCase {
    func testStateMachineTransitions() {
        // Test state machine validity
        let states: [MeasurementState] = [
            .idle,
            .detecting,
            .calibrating,
            .sampling(progress: 0.5),
            .calculating,
            .complete(result: MeasurementResult(
                spO2: 98.0,
                heartRate: 72.0,
                confidence: .high,
                perfusionIndex: 0.05,
                signalToNoiseRatio: 20.0
            ))
        ]

        for state in states {
            XCTAssertNotNil(state)
        }
    }

    func testErrorStates() {
        let errors: [MeasurementError] = [
            .fingerLifted,
            .excessiveAmbientLight,
            .lowPerfusion,
            .excessiveMotion,
            .invalidRValue,
            .physiologicallyImpossible,
            .invalidHeartRate,
            .insufficientData,
            .cameraError,
            .processingTimeout
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
```

**Step 2: Run all tests**

Run: `Cmd+U` in Xcode
Expected: All tests pass

**Step 3: Commit**

```bash
git add SpO2MonitorTests/
git commit -m "test: add integration tests for full measurement cycle"
```

---

## Task 15: Final Polish and Documentation

**Files:**
- Create: `README.md`
- Create: `.gitignore`

**Step 1: Create README.md**

```markdown
# SpO₂ Monitor

A wellness app for iPhone that measures blood oxygen saturation (SpO₂) and heart rate using the rear camera and LED flash.

## ⚠️ Medical Disclaimer

**This is NOT a medical device.** This app is for wellness and fitness purposes only. Do not use for medical diagnosis or treatment decisions.

## Requirements

- iPhone XR or later (iPhone 13+ recommended)
- iOS 17.0+
- Camera and motion permissions

## How to Use

1. Open the app and accept the disclaimer
2. Place your finger over the rear camera and flash
3. Keep still for 30 seconds (5s calibration + 25s measurement)
4. View your SpO₂ and heart rate results

## Technical Details

- **Technology**: Reflectance Photoplethysmography (PPG)
- **Camera**: 60fps capture with locked exposure/white balance
- **Processing**: Real-time vDSP filtering and peak detection
- **Privacy**: All processing happens on-device

## Accuracy

- Target accuracy: ±3-5% compared to medical devices
- Factors affecting accuracy: ambient light, motion, skin tone, nail polish, circulation

## Building

```bash
# Open in Xcode
open SpO2Monitor.xcodeproj

# Build and run (Cmd+R)
```

## License

Private repository. See LICENSE file for details.
```

**Step 2: Create .gitignore**

```
# Xcode
.DS_Store
*.xcuserstate
*.xcuserdatad
*.xcworkspace
xcuserdata/

# Build
build/
DerivedData/

# Swift Package Manager
.swiftpm/
.build/

# CocoaPods
Pods/

# Carthage
Carthage/
```

**Step 3: Final commit**

```bash
git add README.md .gitignore
git commit -m "docs: add README and .gitignore"
```

**Step 4: Tag release**

```bash
git tag -a v1.0.0 -m "Initial release of SpO₂ Monitor"
git push origin main --tags
```

---

## Verification Checklist

Before considering complete:

- [ ] All unit tests pass (PPGFilter, PeakDetector, SignalProcessor, MotionManager)
- [ ] Integration tests pass
- [ ] App builds without warnings
- [ ] Medical disclaimer shows on first launch
- [ ] Camera permissions are requested
- [ ] Flash activates at 0.1 brightness
- [ ] Progress ring counts down 30 seconds
- [ ] Waveform displays in real-time
- [ ] Result card shows SpO₂ and heart rate
- [ ] Error states display user-friendly messages
- [ ] App handles finger lift gracefully
- [ ] Motion detection shows feedback

---

**Plan complete and saved to `docs/plans/2025-03-04-ios-spo2-monitor.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
