//
//  ContentView.swift
//  SpO2 Monitor
//
//  Created on 2026-03-04.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some View {
        if !hasAcceptedDisclaimer {
            OnboardingView(didAccept: {
                hasAcceptedDisclaimer = true
            })
        } else {
            MeasurementView()
        }
    }
}

// Note: Preview removed for SPM compatibility
// #Preview {
//     ContentView()
// }
