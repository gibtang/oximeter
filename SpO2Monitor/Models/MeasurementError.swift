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
