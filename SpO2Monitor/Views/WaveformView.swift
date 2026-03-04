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
