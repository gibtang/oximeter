import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let totalTime: Double // Total seconds

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.red, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)

            // Center text
            VStack(spacing: 4) {
                Text(remainingTime)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(progress < 0.17 ? "Calibrating" : "Measuring")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 240, height: 240)
    }

    private var remainingTime: String {
        let elapsed = totalTime * (1.0 - progress)
        let remaining = max(0, ceil(totalTime - elapsed))
        return "\(Int(remaining))s"
    }
}
