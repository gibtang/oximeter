import Foundation
import SwiftUI

/// Result of a completed SpO₂ measurement
struct MeasurementResult: Identifiable, Equatable, Codable {
    let id: UUID
    let spo2: Double // SpO₂ percentage (70-100%)
    let heartRate: Double // BPM
    let confidence: Double // 0.0 to 1.0
    let timestamp: Date
    let duration: TimeInterval // seconds
    let perfusionIndex: Double
    let signalToNoiseRatio: Double

    init(spo2: Double, heartRate: Double, confidence: Double, duration: TimeInterval, perfusionIndex: Double = 0.0, signalToNoiseRatio: Double = 0.0) {
        self.id = UUID()
        self.spo2 = spo2
        self.heartRate = heartRate
        self.confidence = confidence
        self.timestamp = Date()
        self.duration = duration
        self.perfusionIndex = perfusionIndex
        self.signalToNoiseRatio = signalToNoiseRatio
    }

    var spo2Formatted: String {
        String(format: "%.1f%%", spo2)
    }

    var heartRateFormatted: String {
        String(format: "%.0f", heartRate)
    }

    var spO2Display: String {
        String(format: "%.0f%%", spo2)
    }

    var heartRateDisplay: String {
        String(format: "%.0f BPM", heartRate)
    }

    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
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
