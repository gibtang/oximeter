//
//  ResultCard.swift
//  SpO2Monitor
//
//  Displays the final measurement results including SpO₂ percentage,
//  heart rate, confidence level, and retry button with color-coded
//  health status indicators.
//

import SwiftUI

struct ResultCard: View {
    // MARK: - Properties

    let spo2: Int
    let heartRate: Int
    let confidence: ConfidenceLevel
    let timestamp: Date
    let onRetry: () -> Void

    enum ConfidenceLevel {
        case high
        case medium
        case low
    }

    // MARK: - Computed Properties

    private var spo2Color: Color {
        if spo2 >= 95 {
            return .green
        } else if spo2 >= 90 {
            return .yellow
        } else {
            return .red
        }
    }

    private var confidenceText: String {
        switch confidence {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private var confidenceIcons: String {
        switch confidence {
        case .high: return "✓✓✓"
        case .medium: return "✓✓"
        case .low: return "✓"
        }
    }

    private var confidenceIconColor: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // SpO₂ Display
            VStack(spacing: 8) {
                Text("\(spo2)%")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(spo2Color)
                    .contentTransition(.numericText())

                Text("Blood Oxygen")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Heart Rate Display
            VStack(spacing: 8) {
                Text("\(heartRate) BPM")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())

                Text("Heart Rate")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            // Confidence Indicator
            HStack(spacing: 12) {
                Text(confidenceIcons)
                    .font(.title2)
                    .foregroundColor(confidenceIconColor)

                Text("Confidence: \(confidenceText)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            // Timestamp
            Text("Measured at \(formattedTime)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Retry Button
            Button(action: onRetry) {
                Label("Measure Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 20)

            // Medical Disclaimer Footer
            VStack(spacing: 4) {
                Text("Wellness data only")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Not for medical use")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("Consult a doctor for health concerns")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview("Normal SpO2") {
    ResultCard(
        spo2: 98,
        heartRate: 72,
        confidence: .high,
        timestamp: Date(),
        onRetry: {}
    )
    .background(Color(.systemGroupedBackground))
}

#Preview("Low SpO2") {
    ResultCard(
        spo2: 88,
        heartRate: 95,
        confidence: .low,
        timestamp: Date().addingTimeInterval(-3600),
        onRetry: {}
    )
    .background(Color(.systemGroupedBackground))
}

#Preview("Medium SpO2") {
    ResultCard(
        spo2: 92,
        heartRate: 68,
        confidence: .medium,
        timestamp: Date(),
        onRetry: {}
    )
    .background(Color(.systemGroupedBackground))
}
