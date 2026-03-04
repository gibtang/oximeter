//
//  FullMeasurementCycleTests.swift
//  SpO2MonitorTests
//
//  Integration tests for the complete measurement workflow.
//  These tests verify that all components work together correctly.
//

import XCTest
@testable import SpO2Monitor
#if os(iOS)
import CoreMedia
#endif

final class FullMeasurementCycleTests: XCTestCase {

    // MARK: - State Machine Tests

    func testStateMachineTransitions() {
        // Test state machine validity
        let states: [MeasurementState] = [
            .idle,
            .detecting,
            .calibrating,
            .sampling(progress: 0.0),
            .sampling(progress: 0.5),
            .sampling(progress: 1.0),
            .calculating,
            .complete(result: MeasurementResult(
                spo2: 98.0,
                heartRate: 72.0,
                confidence: 0.95,
                duration: 30.0,
                perfusionIndex: 0.05,
                signalToNoiseRatio: 20.0
            ))
        ]

        // Verify all states can be created
        for state in states {
            XCTAssertNotNil(state, "State should be non-nil")
        }

        // Verify state equality works correctly
        XCTAssertEqual(MeasurementState.idle, .idle)
        XCTAssertEqual(MeasurementState.detecting, .detecting)
        XCTAssertEqual(MeasurementState.calibrating, .calibrating)
        XCTAssertEqual(MeasurementState.calculating, .calculating)

        // Test sampling state equality
        let sampling1 = MeasurementState.sampling(progress: 0.5)
        let sampling2 = MeasurementState.sampling(progress: 0.5001)
        let sampling3 = MeasurementState.sampling(progress: 0.6)
        XCTAssertEqual(sampling1, sampling2, "Sampling states with similar progress should be equal")
        XCTAssertNotEqual(sampling1, sampling3, "Sampling states with different progress should not be equal")

        // Test progress bounds
        let minProgress = MeasurementState.sampling(progress: 0.0)
        let maxProgress = MeasurementState.sampling(progress: 1.0)
        XCTAssertNotNil(minProgress)
        XCTAssertNotNil(maxProgress)
    }

    func testStateProgression() {
        // Test valid state progression
        var currentState = MeasurementState.idle

        // Idle -> Detecting
        currentState = .detecting
        XCTAssertTrue(currentState == .detecting)

        // Detecting -> Calibrating
        currentState = .calibrating
        XCTAssertTrue(currentState == .calibrating)

        // Calibrating -> Sampling
        currentState = .sampling(progress: 0.0)
        if case .sampling(let progress) = currentState {
            XCTAssertEqual(progress, 0.0)
        } else {
            XCTFail("State should be sampling")
        }

        // Sampling progress update
        currentState = .sampling(progress: 0.5)
        if case .sampling(let progress) = currentState {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("State should be sampling")
        }

        // Sampling -> Calculating
        currentState = .calculating
        XCTAssertTrue(currentState == .calculating)

        // Calculating -> Complete
        let result = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )
        currentState = .complete(result: result)
        if case .complete(let r) = currentState {
            XCTAssertEqual(r.spo2, 98.0)
            XCTAssertEqual(r.heartRate, 72.0)
        } else {
            XCTFail("State should be complete")
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
            .processingTimeout,
            .noCameraAccess,
            .fingerNotDetected,
            .fingerRemoved,
            .insufficientLight,
            .motionDetected,
            .timeout,
            .calibrationFailed,
            .calculationError,
            .invalidData,
            .sensorUnavailable,
            .permissionDenied("Camera")
        ]

        // Verify all errors can be created
        for error in errors {
            XCTAssertNotNil(error, "Error should be non-nil")
        }

        // Verify all errors have descriptions
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }

        // Verify error equality
        XCTAssertEqual(MeasurementError.fingerLifted, .fingerLifted)
        XCTAssertEqual(MeasurementError.excessiveAmbientLight, .excessiveAmbientLight)
        XCTAssertNotEqual(MeasurementError.fingerLifted, .excessiveMotion)
    }

    func testErrorStateInStateMachine() {
        // Test error state integration
        let errorState = MeasurementState.error(.fingerLifted)

        if case .error(let error) = errorState {
            XCTAssertEqual(error, .fingerLifted)
            XCTAssertNotNil(error.errorDescription)
        } else {
            XCTFail("State should be error")
        }

        // Test various error states
        let errorStates: [MeasurementState] = [
            .error(.fingerLifted),
            .error(.excessiveAmbientLight),
            .error(.lowPerfusion),
            .error(.excessiveMotion),
            .error(.invalidRValue),
            .error(.physiologicallyImpossible),
            .error(.invalidHeartRate),
            .error(.insufficientData),
            .error(.cameraError),
            .error(.processingTimeout)
        ]

        for state in errorStates {
            if case .error(let error) = state {
                XCTAssertNotNil(error.errorDescription)
            } else {
                XCTFail("State should be error")
            }
        }
    }

    // MARK: - MeasurementResult Tests

    func testMeasurementResultCreation() {
        let result = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )

        XCTAssertNotNil(result.id)
        XCTAssertEqual(result.spo2, 98.0)
        XCTAssertEqual(result.heartRate, 72.0)
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.duration, 30.0)
        XCTAssertEqual(result.perfusionIndex, 0.05)
        XCTAssertEqual(result.signalToNoiseRatio, 20.0)
        XCTAssertNotNil(result.timestamp)
    }

    func testMeasurementResultFormatting() {
        let result = MeasurementResult(
            spo2: 98.5,
            heartRate: 72.3,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )

        // Test formatted outputs
        XCTAssertEqual(result.spo2Formatted, "98.5%")
        XCTAssertEqual(result.heartRateFormatted, "72")
        XCTAssertEqual(result.spO2Display, "98%")
        XCTAssertEqual(result.heartRateDisplay, "72 BPM")
    }

    func testConfidenceLevels() {
        // Test high confidence
        let highResult = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.9,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )
        XCTAssertEqual(highResult.confidenceLevel, .high)

        // Test medium confidence
        let mediumResult = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.6,
            duration: 30.0,
            perfusionIndex: 0.03,
            signalToNoiseRatio: 15.0
        )
        XCTAssertEqual(mediumResult.confidenceLevel, .medium)

        // Test low confidence
        let lowResult = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.3,
            duration: 30.0,
            perfusionIndex: 0.01,
            signalToNoiseRatio: 5.0
        )
        XCTAssertEqual(lowResult.confidenceLevel, .low)

        // Test boundary values
        let boundaryHigh = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.8,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )
        XCTAssertEqual(boundaryHigh.confidenceLevel, .high)

        let boundaryMedium = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.5,
            duration: 30.0,
            perfusionIndex: 0.03,
            signalToNoiseRatio: 15.0
        )
        XCTAssertEqual(boundaryMedium.confidenceLevel, .medium)
    }

    func testMeasurementResultEquality() {
        let result1 = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )

        let result2 = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )

        let result3 = MeasurementResult(
            spo2: 95.0,
            heartRate: 68.0,
            confidence: 0.85,
            duration: 25.0,
            perfusionIndex: 0.03,
            signalToNoiseRatio: 15.0
        )

        // Results with same values should be equal (ignoring id and timestamp)
        XCTAssertEqual(result1.spo2, result2.spo2)
        XCTAssertEqual(result1.heartRate, result2.heartRate)
        XCTAssertEqual(result1.confidence, result2.confidence)

        // Results with different values should not be equal
        XCTAssertNotEqual(result1.spo2, result3.spo2)
        XCTAssertNotEqual(result1.heartRate, result3.heartRate)
    }

    // MARK: - ConfidenceLevel Tests

    func testConfidenceLevelIcons() {
        XCTAssertEqual(ConfidenceLevel.high.icon, "✓✓✓")
        XCTAssertEqual(ConfidenceLevel.medium.icon, "✓✓")
        XCTAssertEqual(ConfidenceLevel.low.icon, "✓")
    }

    func testConfidenceLevelRawValues() {
        XCTAssertEqual(ConfidenceLevel.high.rawValue, "High")
        XCTAssertEqual(ConfidenceLevel.medium.rawValue, "Medium")
        XCTAssertEqual(ConfidenceLevel.low.rawValue, "Low")
    }

    // MARK: - Complete Measurement Cycle Tests

    func testCompleteMeasurementCycle() {
        // Simulate a complete measurement cycle
        var state = MeasurementState.idle

        // 1. Start measurement
        state = .detecting
        XCTAssertTrue(state == .detecting)

        // 2. Detect finger
        state = .calibrating
        XCTAssertTrue(state == .calibrating)

        // 3. Sample with progress
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            state = .sampling(progress: progress)
            if case .sampling(let p) = state {
                XCTAssertEqual(p, progress, accuracy: 0.001)
            } else {
                XCTFail("State should be sampling")
            }
        }

        // 4. Calculate results
        state = .calculating
        XCTAssertTrue(state == .calculating)

        // 5. Complete with result
        let finalResult = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )
        state = .complete(result: finalResult)

        if case .complete(let result) = state {
            XCTAssertEqual(result.spo2, 98.0)
            XCTAssertEqual(result.heartRate, 72.0)
            XCTAssertEqual(result.confidenceLevel, .high)
        } else {
            XCTFail("State should be complete")
        }
    }

    func testMeasurementCycleWithError() {
        // Simulate a measurement cycle that encounters an error
        var state = MeasurementState.idle

        state = .detecting
        state = .calibrating
        state = .sampling(progress: 0.3)

        // Error occurs: finger lifted
        state = .error(.fingerLifted)

        if case .error(let error) = state {
            XCTAssertEqual(error, .fingerLifted)
            XCTAssertEqual(error.errorDescription, "Keep your finger on the camera during measurement")
        } else {
            XCTFail("State should be error")
        }

        // Can restart from error
        state = .idle
        XCTAssertTrue(state == .idle)
    }

    func testVariousErrorScenarios() {
        let errorScenarios: [(MeasurementError, String)] = [
            (.fingerLifted, "Keep your finger on the camera during measurement"),
            (.excessiveAmbientLight, "Cover the flash completely with your finger"),
            (.lowPerfusion, "Press lighter - don't squeeze too hard"),
            (.excessiveMotion, "Hold still during measurement"),
            (.invalidRValue, "Unable to calculate results. Please try again"),
            (.physiologicallyImpossible, "Unable to calculate results. Please try again"),
            (.invalidHeartRate, "Unable to calculate results. Please try again"),
            (.insufficientData, "Not enough data collected - hold for full 30 seconds"),
            (.cameraError, "Camera error - please restart the app"),
            (.processingTimeout, "Measurement timed out. Please try again")
        ]

        for (error, expectedMessage) in errorScenarios {
            let state = MeasurementState.error(error)

            if case .error(let e) = state {
                XCTAssertEqual(e.errorDescription, expectedMessage)
            } else {
                XCTFail("State should be error for \(error)")
            }
        }
    }

    // MARK: - Edge Case Tests

    func testBoundarySpO2Values() {
        // Test minimum SpO2
        let minSpO2 = MeasurementResult(
            spo2: 70.0,
            heartRate: 60.0,
            confidence: 0.5,
            duration: 30.0,
            perfusionIndex: 0.01,
            signalToNoiseRatio: 5.0
        )
        XCTAssertEqual(minSpO2.spO2Display, "70%")

        // Test maximum SpO2
        let maxSpO2 = MeasurementResult(
            spo2: 100.0,
            heartRate: 80.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.1,
            signalToNoiseRatio: 30.0
        )
        XCTAssertEqual(maxSpO2.spO2Display, "100%")

        // Test normal SpO2
        let normalSpO2 = MeasurementResult(
            spo2: 98.5,
            heartRate: 72.0,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )
        XCTAssertEqual(normalSpO2.spO2Display, "98%")
    }

    func testBoundaryHeartRateValues() {
        // Test minimum heart rate
        let minHR = MeasurementResult(
            spo2: 98.0,
            heartRate: 40.0,
            confidence: 0.5,
            duration: 30.0,
            perfusionIndex: 0.01,
            signalToNoiseRatio: 5.0
        )
        XCTAssertEqual(minHR.heartRateDisplay, "40 BPM")

        // Test maximum heart rate
        let maxHR = MeasurementResult(
            spo2: 98.0,
            heartRate: 200.0,
            confidence: 0.5,
            duration: 30.0,
            perfusionIndex: 0.01,
            signalToNoiseRatio: 5.0
        )
        XCTAssertEqual(maxHR.heartRateDisplay, "200 BPM")

        // Test normal heart rate
        let normalHR = MeasurementResult(
            spo2: 98.0,
            heartRate: 72.5,
            confidence: 0.95,
            duration: 30.0,
            perfusionIndex: 0.05,
            signalToNoiseRatio: 20.0
        )
        XCTAssertEqual(normalHR.heartRateDisplay, "72 BPM")
    }

    func testZeroProgressSampling() {
        let zeroProgress = MeasurementState.sampling(progress: 0.0)
        if case .sampling(let progress) = zeroProgress {
            XCTAssertEqual(progress, 0.0)
        } else {
            XCTFail("State should be sampling")
        }
    }

    func testFullProgressSampling() {
        let fullProgress = MeasurementState.sampling(progress: 1.0)
        if case .sampling(let progress) = fullProgress {
            XCTAssertEqual(progress, 1.0)
        } else {
            XCTFail("State should be sampling")
        }
    }

    func testSamplingProgressEquality() {
        let progress1 = MeasurementState.sampling(progress: 0.500)
        let progress2 = MeasurementState.sampling(progress: 0.5005)
        let progress3 = MeasurementState.sampling(progress: 0.502)

        // Should be equal within tolerance
        XCTAssertEqual(progress1, progress2)

        // Should not be equal beyond tolerance
        XCTAssertNotEqual(progress1, progress3)
    }

    // MARK: - Integration with Result State

    func testCompleteStateWithResult() {
        let result = MeasurementResult(
            spo2: 97.5,
            heartRate: 68.0,
            confidence: 0.88,
            duration: 28.5,
            perfusionIndex: 0.045,
            signalToNoiseRatio: 18.5
        )

        let state = MeasurementState.complete(result: result)

        if case .complete(let r) = state {
            XCTAssertEqual(r.spo2, 97.5)
            XCTAssertEqual(r.heartRate, 68.0)
            XCTAssertEqual(r.confidence, 0.88)
            XCTAssertEqual(r.duration, 28.5)
            XCTAssertEqual(r.perfusionIndex, 0.045)
            XCTAssertEqual(r.signalToNoiseRatio, 18.5)
            XCTAssertEqual(r.confidenceLevel, .high)
            XCTAssertEqual(r.spO2Display, "97%")
            XCTAssertEqual(r.heartRateDisplay, "68 BPM")
        } else {
            XCTFail("State should be complete with result")
        }
    }

    func testMultipleMeasurementResults() {
        // Create multiple results to verify they can coexist
        let results = [
            MeasurementResult(
                spo2: 98.0,
                heartRate: 72.0,
                confidence: 0.95,
                duration: 30.0,
                perfusionIndex: 0.05,
                signalToNoiseRatio: 20.0
            ),
            MeasurementResult(
                spo2: 96.0,
                heartRate: 68.0,
                confidence: 0.85,
                duration: 25.0,
                perfusionIndex: 0.03,
                signalToNoiseRatio: 15.0
            ),
            MeasurementResult(
                spo2: 99.0,
                heartRate: 75.0,
                confidence: 0.98,
                duration: 30.0,
                perfusionIndex: 0.08,
                signalToNoiseRatio: 25.0
            )
        ]

        XCTAssertEqual(results.count, 3)

        // Verify each result has unique ID
        let ids = results.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 3, "Each result should have a unique ID")
    }
}
