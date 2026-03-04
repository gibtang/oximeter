//
//  MeasurementView.swift
//  SpO2 Monitor
//
//  Created on 2026-03-04.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Main orchestrator view for SpO2 measurement process.
/// Coordinates CameraManager, SignalProcessor, and MotionManager to handle
/// the complete measurement flow: idle → detecting → calibrating → sampling → calculating → complete/error
@MainActor
struct MeasurementView: View {
    // MARK: - State

    /// Current measurement state
    @State private var state: MeasurementState = .idle

    /// Waveform samples for real-time display
    @State private var waveformSamples: [Double] = []

    /// Feedback message to display to user
    @State private var feedbackMessage: String?

    /// Show alert for permissions
    @State private var showPermissionAlert = false

    // MARK: - Managers

    private let cameraManager = CameraManager()
    private let signalProcessor = SignalProcessor()
    private let motionManager = MotionManager()

    // MARK: - Timing Constants

    /// Calibration phase duration (5 seconds)
    private let calibrationDuration: TimeInterval = 5.0

    /// Sampling phase duration (25 seconds)
    private let samplingDuration: TimeInterval = 25.0

    /// Total measurement duration (30 seconds)
    private let totalDuration: TimeInterval = 30.0

    /// Finger detection confirmation threshold (0.85 normalized red value)
    private let fingerDetectionThreshold: Double = 0.85

    /// Number of consecutive samples required to confirm finger contact
    private let fingerDetectionSampleCount: Int = 60

    /// Motion detection threshold (0.5 variance from baseline)
    private let motionThreshold: Double = 0.5

    // MARK: - Computed Properties

    private var backgroundView: some View {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundView.ignoresSafeArea()

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
                completeView(result: result)
            case .error(let error):
                errorView(error: error)
            }
        }
        .onAppear {
            setupCamera()
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Settings", action: openSettings)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access is required to measure SpO₂. Please enable camera permissions in Settings.")
        }
    }

    // MARK: - Views

    /// Idle state view - instructs user to place finger
    private var idleView: some View {
        VStack(spacing: 30) {
            Spacer()

            // Camera/Flash icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "camera.aperture")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }

            VStack(spacing: 12) {
                Text("Place Your Finger")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Cover the camera and flash completely with your finger")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Illustration
            VStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text("Use the rear camera")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Start button
            Button(action: startDetection) {
                Label("Start Measurement", systemImage: "play.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    /// Detecting state view - shows finger detection progress
    private var detectingView: some View {
        VStack(spacing: 30) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            Text("Detecting finger...")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Make sure your finger covers both the camera and flash")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }

    /// Calibrating state view - shows calibration progress
    private var calibratingView: some View {
        VStack(spacing: 30) {
            Spacer()

            // Progress ring at 17% (calibration phase)
            ProgressRing(progress: 0.17, totalTime: totalDuration)

            Text("Keep your finger still")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Calibrating sensor baseline")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    /// Sampling state view - shows measurement progress with waveform
    private func samplingView(progress: Double) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Progress ring
            ProgressRing(progress: progress, totalTime: totalDuration)

            // Feedback message
            if let message = feedbackMessage {
                Text(message)
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                    .animation(.easeInOut, value: feedbackMessage)
            }

            // Waveform display
            WaveformView(samples: waveformSamples, isRecording: true)
                .padding(.horizontal)

            // Instructions
            Text("Keep your finger steady and don't move")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    /// Calculating state view - shows processing indicator
    private var calculatingView: some View {
        VStack(spacing: 30) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.green)

            Text("Calculating...")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Processing your measurement")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    /// Complete state view - shows final results
    private func completeView(result: MeasurementResult) -> some View {
        ResultCard(
            spo2: Int(result.spo2),
            heartRate: Int(result.heartRate),
            confidence: convertConfidenceLevel(result.confidenceLevel),
            timestamp: result.timestamp,
            onRetry: resetToIdle
        )
    }

    /// Converts ConfidenceLevel from model to view format
    private func convertConfidenceLevel(_ level: ConfidenceLevel) -> ResultCard.ConfidenceLevel {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    /// Error state view - shows error message and retry option
    private func errorView(error: MeasurementError) -> some View {
        VStack(spacing: 30) {
            Spacer()

            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
            }

            VStack(spacing: 12) {
                Text("Measurement Error")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(error.errorDescription ?? "An unknown error occurred")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Retry button
            Button(action: resetToIdle) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logic Methods

    /// Sets up the camera session
    private func setupCamera() {
        Task {
            do {
                try await cameraManager.setupCamera()
            } catch {
                print("Camera setup error: \(error)")
                await MainActor.run {
                    state = .error(.noCameraAccess)
                    showPermissionAlert = true
                }
            }
        }
    }

    /// Starts finger detection phase
    private func startDetection() {
        Task {
            await MainActor.run {
                state = .detecting
                waveformSamples.removeAll()
                feedbackMessage = nil
            }

            // Start camera session and motion monitoring
            await cameraManager.startSession()
            await cameraManager.setTorch(enabled: true)
            await motionManager.startMonitoring()

            // Confirm finger contact
            await confirmFingerContact()
        }
    }

    /// Confirms finger is properly placed on camera
    /// Requires 60 consecutive samples with red channel > 0.85
    private func confirmFingerContact() async {
        var confirmedSamples = 0
        let startTime = Date()
        let timeout: TimeInterval = 10.0 // 10 second timeout

        // Stream samples and detect finger
        let stream = await cameraManager.samplePublisher
        for await sample in stream {
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                await MainActor.run {
                    state = .error(.fingerNotDetected)
                }
                cleanup()
                return
            }

            // Check if red value exceeds threshold
            if sample.red > fingerDetectionThreshold {
                confirmedSamples += 1

                // Update waveform with red channel
                await MainActor.run {
                    waveformSamples.append(sample.red)
                    // Keep only recent samples for display
                    if waveformSamples.count > 300 {
                        waveformSamples.removeFirst()
                    }
                }

                // Confirm finger detection after required samples
                if confirmedSamples >= fingerDetectionSampleCount {
                    // Start sampling phase
                    await startSampling()
                    return
                }
            } else {
                // Reset counter if finger not detected
                confirmedSamples = 0
            }
        }
    }

    /// Starts the measurement sampling phase (5s calibration + 25s sampling)
    private func startSampling() async {
        await MainActor.run {
            state = .calibrating
        }

        var samples: [PPGSample] = []
        let startTime = Date()
        var lastErrorCheck = Date()

        // Stream samples for full duration
        let stream = await cameraManager.samplePublisher
        for await sample in stream {
            let currentTime = Date()
            let elapsed = currentTime.timeIntervalSince(startTime)

            // Check for errors periodically
            if currentTime.timeIntervalSince(lastErrorCheck) > 0.5 {
                if let error = await checkForErrors(sample: sample) {
                    await MainActor.run {
                        state = .error(error)
                    }
                    cleanup()
                    return
                }
                lastErrorCheck = currentTime
            }

            // Add sample to collection
            samples.append(sample)

            // Update waveform display
            await MainActor.run {
                waveformSamples.append(sample.red)
                if waveformSamples.count > 300 {
                    waveformSamples.removeFirst()
                }
            }

            // Transition from calibration to sampling
            if elapsed >= calibrationDuration, case .calibrating = state {
                await MainActor.run {
                    state = .sampling(progress: 0.17)
                }
            }

            // Update progress during sampling phase
            if elapsed > calibrationDuration {
                let samplingProgress = (elapsed - calibrationDuration) / samplingDuration
                let overallProgress = 0.17 + (samplingProgress * 0.83) // 17% + 83%

                await MainActor.run {
                    state = .sampling(progress: overallProgress)
                }
            }

            // Check if measurement complete
            if elapsed >= totalDuration {
                await calculateResults(samples: samples)
                return
            }
        }
    }

    /// Checks for measurement errors based on sample quality and motion
    private func checkForErrors(sample: PPGSample) async -> MeasurementError? {
        // Check finger contact
        if sample.red < 0.3 {
            return .fingerRemoved
        }

        // Check for excessive light (values too high)
        if sample.red > 0.98 || sample.blue > 0.98 {
            return .excessiveAmbientLight
        }

        // Check for insufficient light
        if sample.red < 0.1 && sample.blue < 0.1 {
            return .insufficientLight
        }

        // Check motion
        if await motionManager.isExcessiveMotion(threshold: motionThreshold) {
            return .motionDetected
        }

        return nil
    }

    /// Calculates final measurement results from collected samples
    private func calculateResults(samples: [PPGSample]) async {
        await MainActor.run {
            state = .calculating
        }

        // Stop sampling
        cleanup()

        // Process samples
        if let result = await signalProcessor.process(samples: samples) {
            await MainActor.run {
                state = .complete(result: result)
            }
        } else {
            await MainActor.run {
                state = .error(.calculationError)
            }
        }
    }

    /// Resets measurement state to idle
    private func resetToIdle() {
        state = .idle
        waveformSamples.removeAll()
        feedbackMessage = nil

        // Restart camera setup
        setupCamera()
    }

    /// Cleans up resources after measurement
    private func cleanup() {
        Task {
            await cameraManager.setTorch(enabled: false)
            await cameraManager.stopSession()
            await motionManager.stopMonitoring()
        }
    }

    /// Opens app settings
    private func openSettings() {
        #if canImport(UIKit)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        #endif
    }
}

// Note: Preview removed for SPM compatibility
// #Preview("Idle State") {
//     MeasurementView()
// }
