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
