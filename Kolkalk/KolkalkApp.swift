// Kolkalk/KolkalkApp.swift

import SwiftUI
// Importera UIKit för AppDelegate om du inte redan gjort det
import UIKit

@main
struct Kolkalk_iOSApp: App {
    // Koppla AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // *** ÄNDRING: Ta bort StateObject härifrån, de skapas i ContentView ***
    // @StateObject var foodData = FoodData_iOS()
    // @StateObject var viewModel = ViewModel.shared

    var body: some Scene {
        WindowGroup {
            // *** ÄNDRING: Skapa ContentView utan parametrar ***
            ContentView()
                .onAppear {
                     requestNotificationAuthorization()
                }
        }
    }

    // Funktion för att begära notisbehörighet (behåll denna)
    func requestNotificationAuthorization() {
         let center = UNUserNotificationCenter.current()
         center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
              if granted {
                   print("iOSApp: Notification permission granted.")
                   // Registrera på huvudtråden
                   DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                   }
              } else if let error = error {
                   print("iOSApp: Notification permission denied: \(error.localizedDescription)")
              }
         }
     }
}
