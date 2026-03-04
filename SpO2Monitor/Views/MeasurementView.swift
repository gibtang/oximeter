//
//  MeasurementView.swift
//  SpO2 Monitor
//
//  Created on 2026-03-04.
//

import SwiftUI

struct MeasurementView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            Text("SpO₂ Measurement")
                .font(.title)
                .fontWeight(.bold)

            Text("Coming Soon")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("The measurement interface will be implemented in upcoming tasks.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
    }
}

// Note: Preview removed for SPM compatibility
// #Preview {
//     MeasurementView()
// }
