//
//  SettingsView.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-01.
//


// Kolkalk.zip/kolkalk Watch App/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    // Använd @AppStorage för att binda till UserDefaults
    // 'enableCarbLogging' och 'enableInsulinLogging' är nycklarna i UserDefaults.
    // 'true' är standardvärdet om nyckeln inte finns.
    @AppStorage("enableCarbLogging") private var enableCarbLogging = true
    @AppStorage("enableInsulinLogging") private var enableInsulinLogging = true

    var body: some View {
        Form {
            Section(header: Text("Apple Hälsa")) {
                Toggle("Logga kolhydrater", isOn: $enableCarbLogging)
                Toggle("Visa Logga Insulin", isOn: $enableInsulinLogging)
            }

            Section(header: Text("Om")) {
                 Text("Kolkalk v1.0") // Du kan uppdatera med din version
                 // Lägg eventuellt till mer information här
            }
        }
        .navigationTitle("Inställningar")
        // Begär HealthKit-auktorisering om någon funktion slås på (om den inte redan är given)
        .onChange(of: enableCarbLogging) { requestAuthIfEnabled() }
        .onChange(of: enableInsulinLogging) { requestAuthIfEnabled() }
    }

    // Funktion för att begära auktorisering om någon av funktionerna är påslagna
    private func requestAuthIfEnabled() {
        if enableCarbLogging || enableInsulinLogging {
            HealthKitManager.shared.requestAuthorization { success, error in
                if !success {
                    print("HealthKit authorization was not granted after toggle.")
                    // Du kan visa ett felmeddelande för användaren här om det behövs
                }
            }
        }
    }
}

// Förhandsvisning (valfritt)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}