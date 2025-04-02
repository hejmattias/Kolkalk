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
        HealthKitManager.shared.requestAuthorization { success, error in
            // ... befintlig kod ...
        }
    }

    var body: some Scene {
        WindowGroup {
            // Omslut ContentView med NavigationView om den inte redan har det
            // för att säkerställa att titlar etc. fungerar korrekt.
            NavigationView {
                 ContentView()
            }
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
