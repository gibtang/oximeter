import Foundation

/// Errors that can occur during measurement
enum MeasurementError: Error, Equatable, LocalizedError {
    case noCameraAccess
    case fingerNotDetected
    case fingerRemoved
    case fingerLifted
    case insufficientLight
    case excessiveAmbientLight
    case lowPerfusion
    case motionDetected
    case excessiveMotion
    case timeout
    case processingTimeout
    case calibrationFailed
    case calculationError
    case invalidData
    case invalidRValue
    case physiologicallyImpossible
    case invalidHeartRate
    case insufficientData
    case cameraError
    case sensorUnavailable
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .noCameraAccess:
            return "Camera access is required to measure SpO₂"
        case .fingerNotDetected:
            return "Place your finger over the camera to begin"
        case .fingerRemoved, .fingerLifted:
            return "Keep your finger on the camera during measurement"
        case .insufficientLight:
            return "Move to a better lit area or enable flash"
        case .excessiveAmbientLight:
            return "Cover the flash completely with your finger"
        case .lowPerfusion:
            return "Press lighter - don't squeeze too hard"
        case .motionDetected, .excessiveMotion:
            return "Hold still during measurement"
        case .timeout, .processingTimeout:
            return "Measurement timed out. Please try again"
        case .calibrationFailed:
            return "Unable to calibrate sensor. Please try again"
        case .calculationError, .invalidRValue, .physiologicallyImpossible, .invalidHeartRate:
            return "Unable to calculate results. Please try again"
        case .invalidData:
            return "Invalid measurement data received"
        case .insufficientData:
            return "Not enough data collected - hold for full 30 seconds"
        case .cameraError:
            return "Camera error - please restart the app"
        case .sensorUnavailable:
            return "Camera sensor is unavailable"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        }
    }
}
