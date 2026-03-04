//
//  SpO2MonitorApp.swift
//  SpO2 Monitor
//
//  Created on 2026-03-04.
//

import SwiftUI

@main
struct SpO2MonitorApp: App {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
