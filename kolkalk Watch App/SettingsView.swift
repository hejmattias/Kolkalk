//
//  SettingsView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-01.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("enableCarbLogging") private var enableCarbLogging = false
    @AppStorage("enableInsulinLogging") private var enableInsulinLogging = false

    // Dynamiskt hämtad version och build från Info.plist
    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Kolkalk v\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section(header: Text("Apple Hälsa")) {
                Toggle("Visa Logga kolhydrater", isOn: $enableCarbLogging)
                Toggle("Visa Logga Insulin", isOn: $enableInsulinLogging)
            }

            Section(header: Text("Om")) {
                Text(appVersionString) // Nu visas alltid aktuell version och build
            }
        }
        .navigationTitle("Inställningar")
        .onChange(of: enableCarbLogging) { requestAuthIfEnabled() }
        .onChange(of: enableInsulinLogging) { requestAuthIfEnabled() }
    }

    private func requestAuthIfEnabled() {
        if enableCarbLogging || enableInsulinLogging {
            HealthKitManager.shared.requestAuthorization { success, error in
                if !success {
                    print("HealthKit authorization was not granted after toggle.")
                } else {
                    print("HealthKit authorization granted or already available after toggle.")
                }
            }
        } else {
            print("Both HealthKit features disabled in settings.")
        }
    }
}

// Förhandsvisning (valfritt)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UserDefaults.standard.removeObject(forKey: "enableCarbLogging")
        UserDefaults.standard.removeObject(forKey: "enableInsulinLogging")
        return NavigationView {
            SettingsView()
        }
    }
}
