// kolkalk Watch App/kolkalkApp.swift

import SwiftUI
import WatchKit // Importera WatchKit
import UserNotifications // Importera UserNotifications
// Ta bort: import CloudKit (behövs inte direkt här)

@main
struct MyApp: App {
    // *** NYTT: Koppla ExtensionDelegate ***
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate

    // Initialize HealthKitManager (behåll)
    init() {
        // ***** ÄNDRING: Ta bort automatisk auktoriseringsförfrågan härifrån *****
        // HealthKitManager.shared.requestAuthorization { success, error in
        //     // ... befintlig kod ...
        //     // Ingen ändring här behövs
        //      if let error = error {
        //           print("HealthKitManager auth error: \(error.localizedDescription)")
        //      } else if success {
        //           print("HealthKitManager auth success.")
        //      } else {
        //           print("HealthKitManager auth denied.")
        //      }
        // }
        // ***** SLUT ÄNDRING *****
        print("HealthKitManager initialized (initial auth request removed).")
    }

    var body: some Scene {
        WindowGroup {
            // ***** ÄNDRING: Ta bort NavigationView härifrån *****
            // NavigationView { // <--- DENNA RAD TAS BORT
                 ContentView() // ContentView använder redan NavigationStack internt
            // } // <--- DENNA RAD TAS BORT
             .onAppear {
                  // Begär notisbehörighet när appen startar/visas
                   requestWatchNotificationAuthorization()
             }
        }
    }

     // *** NYTT: Funktion för att begära notisbehörighet för klockan ***
     func requestWatchNotificationAuthorization() {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
               if granted {
                    print("WatchApp: Notification authorization granted.")
                    // Registrera för notiser på huvudtråden
                    DispatchQueue.main.async {
                         WKExtension.shared().registerForRemoteNotifications()
                    }
               } else if let error = error {
                    print("WatchApp: Notification authorization failed: \(error.localizedDescription)")
               }
          }
     }
}
