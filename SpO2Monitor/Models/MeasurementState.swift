//
//  MeasurementState.swift
//  SpO2 Monitor
//
//  Created on 2026-03-04.
//

import Foundation

/// Represents the current state of the SpO₂ measurement process
enum MeasurementState: Equatable {
    /// Initial state - no measurement in progress
    case idle

    /// Attempting to detect finger on camera
    case detecting

    /// Calibrating sensor baseline
    case calibrating

    /// Sampling PPG data with progress (0.0 to 1.0)
    case sampling(progress: Double)

    /// Processing sampled data to calculate results
    case calculating

    /// Measurement completed successfully
    case complete(result: MeasurementResult)

    /// An error occurred during measurement
    case error(MeasurementError)

    static func == (lhs: MeasurementState, rhs: MeasurementState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.detecting, .detecting),
             (.calibrating, .calibrating),
             (.calculating, .calculating):
            return true
        case let (.sampling(lhsProgress), .sampling(rhsProgress)):
            return abs(lhsProgress - rhsProgress) < 0.001
        case let (.complete(lhsResult), .complete(rhsResult)):
            return lhsResult == rhsResult
        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

/// Result of a completed SpO₂ measurement
struct MeasurementResult: Equatable, Codable {
    let spo2: Double // SpO₂ percentage (70-100%)
    let heartRate: Double // BPM
    let confidence: Double // 0.0 to 1.0
    let timestamp: Date
    let duration: TimeInterval // seconds

    var spo2Formatted: String {
        String(format: "%.1f%%", spo2)
    }

    var heartRateFormatted: String {
        String(format: "%.0f", heartRate)
    }
}

/// Errors that can occur during measurement
enum MeasurementError: Error, Equatable {
    case noCameraAccess
    case fingerNotDetected
    case fingerRemoved
    case insufficientLight
    case motionDetected
    case timeout
    case calibrationFailed
    case calculationError
    case invalidData
    case sensorUnavailable
    case permissionDenied(String)

    var localizedDescription: String {
        switch self {
        case .noCameraAccess:
            return "Camera access is required to measure SpO₂"
        case .fingerNotDetected:
            return "Place your finger over the camera to begin"
        case .fingerRemoved:
            return "Keep your finger on the camera during measurement"
        case .insufficientLight:
            return "Move to a better lit area or enable flash"
        case .motionDetected:
            return "Keep your hand steady during measurement"
        case .timeout:
            return "Measurement timed out. Please try again"
        case .calibrationFailed:
            return "Unable to calibrate sensor. Please try again"
        case .calculationError:
            return "Unable to calculate results. Please try again"
        case .invalidData:
            return "Invalid measurement data received"
        case .sensorUnavailable:
            return "Camera sensor is unavailable"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        }
    }
}
