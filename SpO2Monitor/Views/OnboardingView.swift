//
//  OnboardingView.swift
//  SpO2 Monitor
//
//  Created on 2026-03-04.
//

import SwiftUI

struct OnboardingView: View {
    let didAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("IMPORTANT HEALTH INFORMATION")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text("Please read carefully before using this app")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

                // Wellness Tool Notice
                VStack(alignment: .leading, spacing: 8) {
                    Label("This app is a WELLNESS and FITNESS tool only", systemImage: "heart.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("This application is designed for general wellness purposes and fitness tracking. It provides estimated SpO2 readings for informational purposes only.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // NOT A MEDICAL DEVICE Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOT A MEDICAL DEVICE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    DisclaimerPoint(text: "This app is NOT intended for medical diagnosis, treatment, or monitoring of any medical condition")
                    DisclaimerPoint(text: "This app has NOT been evaluated or approved by the FDA or any medical regulatory body")
                    DisclaimerPoint(text: "This app should NEVER replace professional medical equipment or medical advice")
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)

                // ACCURACY LIMITATIONS Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACCURACY LIMITATIONS")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)

                    DisclaimerPoint(text: "Readings may be inaccurate due to finger placement, movement, temperature, nail polish, or skin pigmentation")
                    DisclaimerPoint(text: "This app uses your device's camera and light sensor, which are not medical-grade sensors")
                    DisclaimerPoint(text: "Accuracy may vary significantly between individuals and devices")
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

                // WHEN TO SEEK MEDICAL CARE Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHEN TO SEEK MEDICAL CARE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    DisclaimerPoint(text: "If you experience symptoms like shortness of breath, chest pain, confusion, or bluish lips/face, seek immediate medical attention")
                    DisclaimerPoint(text: "Consult a healthcare professional for accurate SpO2 measurement if you have concerns about your oxygen levels")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Acknowledgment Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("BY USING THIS APP, YOU ACKNOWLEDGE THAT:")
                        .font(.headline)
                        .fontWeight(.bold)

                    DisclaimerPoint(text: "You understand this is NOT a medical device and readings are estimates only")
                    DisclaimerPoint(text: "You will NOT rely on this app for medical decisions or diagnosis")
                    DisclaimerPoint(text: "The developers are NOT responsible for any health consequences resulting from use of this app")
                    DisclaimerPoint(text: "You should consult a healthcare professional for medical concerns")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: didAccept) {
                        Text("I Understand and Accept")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        exit(0)
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .navigationTitle("Disclaimer")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct DisclaimerPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chevron.right.circle.fill")
                .foregroundColor(.red)
                .font(.caption)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// Note: Preview removed for SPM compatibility
// #Preview {
//     OnboardingView(didAccept: {})
// }
