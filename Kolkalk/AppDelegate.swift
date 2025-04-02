// Kolkalk/AppDelegate.swift

import UIKit
import CloudKit
import UserNotifications // Importera UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Sätt denna klass som delegate för notiscenter för att hantera notiser när appen är öppen
        UNUserNotificationCenter.current().delegate = self
        // Registrera appen för att ta emot fjärrnotiser (inklusive tysta CloudKit-notiser)
        application.registerForRemoteNotifications()
        print("AppDelegate: Application finished launching and registered for remote notifications.")
        return true
    }

    // MARK: - Remote Notifications Handling

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Körs när appen lyckats registrera sig för fjärrnotiser hos APNS
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("AppDelegate: Successfully registered for remote notifications with Device Token: \(token)")
        // Ingen ytterligare åtgärd behövs oftast för CloudKit här
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Körs när appen misslyckades att registrera sig för fjärrnotiser
        print("AppDelegate Error: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Denna metod anropas när en push-notis tas emot (både vanliga och tysta)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("AppDelegate: Received remote notification (raw): \(userInfo)")

        // Försök tolka notisen som en CloudKit-notis
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
             print("AppDelegate: Notification is from CloudKit.")

             // Kontrollera om det är en notis om en ändring i en query (det vanligaste för prenumerationer)
             if let queryNotification = notification as? CKQueryNotification {
                 let subscriptionID = queryNotification.subscriptionID
                 print("AppDelegate: Received Query Notification with SubscriptionID: \(subscriptionID ?? "N/A")")

                 var dataChanged = false // Flagga för att se om vi hanterade notisen

                 // Anropa rätt hanterare baserat på Subscription ID
                 if subscriptionID == "fooditem-changes-subscription" {
                    print("AppDelegate: Handling FoodItem change notification...")
                    CloudKitFoodDataStore.shared.handleNotification() // Signalera FoodData_iOS
                    dataChanged = true
                 } else if subscriptionID == "container-changes-subscription" {
                     print("AppDelegate: Handling Container change notification...")
                     CloudKitContainerDataStore.shared.handleContainerNotification() // Signalera ContainerData
                     dataChanged = true
                 } else {
                     print("AppDelegate Warning: Notification received for unknown or unhandled subscription ID: \(subscriptionID ?? "N/A")")
                     // Du kan välja att uppdatera båda här för säkerhets skull om du vill
                 }

                 // Meddela systemet om data hämtades eller inte
                 completionHandler(dataChanged ? .newData : .noData)

             } else {
                 // Annan typ av CloudKit-notis (t.ex. CKDatabaseNotification, CKRecordZoneNotification)
                 // Dessa är mindre vanliga för den typ av prenumeration vi satt upp.
                 print("AppDelegate: Received a non-query CKNotification type: \(type(of: notification))")
                 completionHandler(.noData) // Antagligen ingen relevant data för våra listor
             }
         } else {
             // Notisen var inte från CloudKit
             print("AppDelegate: Notification is NOT from CloudKit.")
             completionHandler(.noData)
         }
    }

    // MARK: - UNUserNotificationCenterDelegate (För notiser när appen är aktiv)

    // Anropas när en notis tas emot MEDAN appen är i förgrunden
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("AppDelegate: Notification will present while app is active.")

        // För tysta CloudKit-notiser vill vi INTE visa någon alert/ljud/badge för användaren.
        // De ska bara trigga en datauppdatering i bakgrunden.
        if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
             print("AppDelegate: It's a silent CloudKit notification, suppressing presentation.")
             // Hanteringen sker redan i didReceiveRemoteNotification, visa inget extra.
             completionHandler([]) // Tom array = visa inget (inget ljud, ingen banner, etc.)
        } else {
             print("AppDelegate: It's another type of notification, allowing standard presentation.")
             // Om du har ANDRA typer av push-notiser kan du låta dem visas normalt här:
             if #available(iOS 14.0, *) {
                 completionHandler([.banner, .list, .sound, .badge])
             } else {
                 completionHandler([.alert, .sound, .badge]) // Fallback för äldre iOS
             }
        }
    }

    // Anropas när användaren interagerar med en (synlig) notis (klickar på den)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("AppDelegate: User interacted with notification.")

        // Här kan du lägga till logik om något speciellt ska hända när användaren
        // klickar på en notis (om du har andra notiser än de tysta från CloudKit).
        // För CloudKit-notiserna behövs oftast inget här, eftersom datan redan uppdaterats.

        // Exempel: Om du har en kategori i notisen kan du navigera till en viss vy.
        // let categoryIdentifier = response.notification.request.content.categoryIdentifier
        // if categoryIdentifier == "MIN_SPECIELLA_NOTIS_KATEGORI" { /* Navigera... */ }

        completionHandler() // Viktigt att anropa completionHandler när du är klar
    }
}
