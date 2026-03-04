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

// Note: MeasurementResult and MeasurementError are defined in separate files
// to avoid duplication and improve code organization
