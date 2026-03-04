import Foundation
import CoreMedia

struct PPGSample: Sendable {
    let red: Double      // Normalized 0.0-1.0
    let blue: Double     // Normalized 0.0-1.0
    let timestamp: CMTime
}
