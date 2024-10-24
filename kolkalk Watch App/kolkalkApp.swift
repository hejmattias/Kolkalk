// kolkalk Watch App/kolkalkApp.swift

import SwiftUI
import HealthKit

@main
struct MyApp: App {
    // Initialize HealthKitManager
    init() {
        HealthKitManager.shared.requestAuthorization { success, error in
            if let error = error {
                print("HealthKit Authorization Failed: \(error.localizedDescription)")
            } else {
                print("HealthKit Authorization Succeeded")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView() // Startar appen med ContentView
        }
    }
}

