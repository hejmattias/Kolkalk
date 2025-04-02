// kolkalk Watch App/ExtensionDelegate.swift

import WatchKit
import CloudKit
import UserNotifications // Importera UserNotifications

// Klassen ÄR NSObject och konformar till WKExtensionDelegate
class ExtensionDelegate: NSObject, WKExtensionDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching() {
        // Denna metod körs när klockappen startar
        print("ExtensionDelegate: applicationDidFinishLaunching")
         // Sätt denna klass som delegate för notiscenter
         UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidBecomeActive() {
        // Denna metod körs när klockappen blir aktiv
        print("ExtensionDelegate: applicationDidBecomeActive")
    }

    func applicationWillResignActive() {
        // Denna metod körs när klockappen blir inaktiv
        print("ExtensionDelegate: applicationWillResignActive")
    }

    // MARK: - Remote Notifications

    // Körs när klockan lyckats registrera sig för fjärrnotiser
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("ExtensionDelegate: Device Token: \(token)")
    }

    // Körs när klockan misslyckades att registrera sig
    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("ExtensionDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Hantera mottagen push-notis (viktigast för CloudKit)
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        print("ExtensionDelegate: Received remote notification (raw): \(userInfo)")

        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
             print("ExtensionDelegate: Notification is from CloudKit.")
            CloudKitFoodDataStore.shared.handleNotification()
            completionHandler(.newData) // Signalera att ny data finns
         } else {
             print("ExtensionDelegate: Notification is NOT from CloudKit.")
             completionHandler(.noData)
         }
    }


     // MARK: - UNUserNotificationCenterDelegate (Valfritt men bra för felsökning)

     // Anropas när en notis tas emot MEDAN appen är i förgrunden
     func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
         print("ExtensionDelegate: Will present notification while app is active.")
         // För tysta CloudKit-notiser vill vi oftast inte visa något
         if CKNotification(fromRemoteNotificationDictionary: notification.request.content.userInfo) != nil {
              print("ExtensionDelegate: It's a silent CloudKit notification, suppressing presentation.")
              completionHandler([])
         } else {
              print("ExtensionDelegate: It's another type of notification, allowing presentation.")
              completionHandler([.banner, .sound]) // Anpassa efter behov för klockan
         }
     }

     // Anropas när användaren interagerar med en notis
     func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
         print("ExtensionDelegate: User interacted with notification.")
         // Hantera interaktion här om nödvändigt
         completionHandler()
     }
}
