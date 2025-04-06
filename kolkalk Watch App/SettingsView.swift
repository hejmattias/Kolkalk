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
    // ***** ÄNDRING: Standardvärdet är nu false *****
    @AppStorage("enableCarbLogging") private var enableCarbLogging = false
    @AppStorage("enableInsulinLogging") private var enableInsulinLogging = false
    // ***** SLUT ÄNDRING *****

    var body: some View {
        Form {
            Section(header: Text("Apple Hälsa")) {
                Toggle("Visa Logga kolhydrater", isOn: $enableCarbLogging)
                Toggle("Visa Logga Insulin", isOn: $enableInsulinLogging)
            }

            Section(header: Text("Om")) {
                 Text("Kolkalk v1.0") // Du kan uppdatera med din version
                 // Lägg eventuellt till mer information här
            }
        }
        .navigationTitle("Inställningar")
        // Begär HealthKit-auktorisering om någon funktion slås på (om den inte redan är given)
        // Denna logik behålls eftersom den endast körs när värdet ändras TILL true (eller från true till false)
        .onChange(of: enableCarbLogging) { requestAuthIfEnabled() }
        .onChange(of: enableInsulinLogging) { requestAuthIfEnabled() }
    }

    // Funktion för att begära auktorisering om någon av funktionerna är påslagna
    // Denna funktion är korrekt och behövs fortfarande för .onChange
    private func requestAuthIfEnabled() {
        // Kolla om *någon* av funktionerna är påslagen
        if enableCarbLogging || enableInsulinLogging {
            // Begär bara auktorisering. HealthKit hanterar internt om den redan är given.
            HealthKitManager.shared.requestAuthorization { success, error in
                if !success {
                    // Logga om auktorisering nekades *efter* att användaren försökt slå på den
                    print("HealthKit authorization was not granted after toggle.")
                    // Eventuellt: Informera användaren att funktionen inte kommer fungera utan tillåtelse.
                    // Eventuellt: Stäng av togglen igen om auktorisering nekas?
                    // if let error = error { print("Auth error: \(error.localizedDescription)") }
                } else {
                    print("HealthKit authorization granted or already available after toggle.")
                }
            }
        } else {
             // Om båda togglarna stängs av behöver vi inte göra något med auktoriseringen.
             print("Both HealthKit features disabled in settings.")
        }
    }
}

// Förhandsvisning (valfritt)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Återställ AppStorage för förhandsvisningen för att se standardvärdet false
        UserDefaults.standard.removeObject(forKey: "enableCarbLogging")
        UserDefaults.standard.removeObject(forKey: "enableInsulinLogging")
        return NavigationView {
            SettingsView()
        }
    }
}
