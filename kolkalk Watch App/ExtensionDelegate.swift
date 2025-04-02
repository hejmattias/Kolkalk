// kolkalk Watch App/ExtensionDelegate.swift

import WatchKit
import CloudKit
import UserNotifications // Importera UserNotifications

// Klassen ÄR NSObject och konformar till WKExtensionDelegate och UNUserNotificationCenterDelegate
class ExtensionDelegate: NSObject, WKExtensionDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching() {
        // Körs när klockappen startar (både i förgrunden och bakgrunden)
        print("ExtensionDelegate: applicationDidFinishLaunching.")
        // Sätt denna klass som delegate för notiscenter
        UNUserNotificationCenter.current().delegate = self
        // Registrera för fjärrnotiser (behövs för att ta emot CloudKit push)
        WKExtension.shared().registerForRemoteNotifications()
        print("ExtensionDelegate: Registered for remote notifications.")
    }

    func applicationDidBecomeActive() {
        // Körs när klockappen blir aktiv (synlig för användaren)
        print("ExtensionDelegate: applicationDidBecomeActive.")
    }

    func applicationWillResignActive() {
        // Körs när klockappen blir inaktiv
        print("ExtensionDelegate: applicationWillResignActive.")
    }

    // MARK: - Remote Notifications Handling

    // Körs när klockan lyckats registrera sig för fjärrnotiser
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("ExtensionDelegate: Successfully registered for remote notifications with Device Token: \(token)")
    }

    // Körs när klockan misslyckades att registrera sig
    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("ExtensionDelegate Error: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Hantera mottagen push-notis (detta är nyckeln för CloudKit-uppdateringar)
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        print("ExtensionDelegate: Received remote notification (raw): \(userInfo)")

        // Försök tolka notisen som en CloudKit-notis
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
             print("ExtensionDelegate: Notification is from CloudKit.")

             // Kontrollera om det är en notis om en ändring i en query
             if let queryNotification = notification as? CKQueryNotification {
                 let subscriptionID = queryNotification.subscriptionID
                 print("ExtensionDelegate: Received Query Notification with SubscriptionID: \(subscriptionID ?? "N/A")")

                 var dataChanged = false // Flagga

                 // Anropa rätt hanterare baserat på Subscription ID
                 if subscriptionID == "fooditem-changes-subscription" {
                    print("ExtensionDelegate: Handling FoodItem change notification...")
                    CloudKitFoodDataStore.shared.handleNotification() // Signalera FoodData
                    dataChanged = true
                 } else if subscriptionID == "container-changes-subscription" {
                     print("ExtensionDelegate: Handling Container change notification...")
                     CloudKitContainerDataStore.shared.handleContainerNotification() // Signalera WatchContainerData
                     dataChanged = true
                 } else {
                      print("ExtensionDelegate Warning: Notification received for unknown or unhandled subscription ID: \(subscriptionID ?? "N/A")")
                 }

                 // Meddela systemet om ny data finns
                 completionHandler(dataChanged ? .newData : .noData)

             } else {
                 print("ExtensionDelegate: Received a non-query CKNotification type: \(type(of: notification))")
                 completionHandler(.noData)
             }
         } else {
             print("ExtensionDelegate: Notification is NOT from CloudKit.")
             completionHandler(.noData)
         }
    }


     // MARK: - UNUserNotificationCenterDelegate (För notiser när appen är aktiv)

     // Anropas när en notis tas emot MEDAN klockappen är i förgrunden
     func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
         let userInfo = notification.request.content.userInfo
         print("ExtensionDelegate: Notification will present while app is active.")

         // Tysta CloudKit-notiser ska inte visas för användaren
         if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
              print("ExtensionDelegate: It's a silent CloudKit notification, suppressing presentation.")
              completionHandler([]) // Visa inget
         } else {
              print("ExtensionDelegate: It's another type of notification, allowing presentation.")
              // För andra notiser, bestäm hur de ska visas på klockan
              if #available(watchOS 7.0, *) {
                  completionHandler([.banner, .sound]) // Standard på watchOS
              } else {
                  completionHandler([.sound]) // Fallback
              }
         }
     }

     // Anropas när användaren interagerar med en (synlig) notis
     func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
         let userInfo = response.notification.request.content.userInfo
         print("ExtensionDelegate: User interacted with notification.")
         // Lägg till eventuell logik för notis-interaktion här
         completionHandler()
     }
}
