//
//  AppDelegate.swift
//  Kolkalk
//
//  Created by Mattias Göransson on 2025-04-01.
//


// Kolkalk/AppDelegate.swift

import UIKit
import CloudKit
import UserNotifications // Importera UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate { // Lägg till UNUserNotificationCenterDelegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Sätt denna klass som delegate för notiscenter för att hantera notiser när appen är öppen
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote Notifications

    // Körs när appen lyckats registrera sig för fjärrnotiser hos APNS
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("AppDelegate: Device Token: \(token)")
        // Du behöver oftast inte göra något mer med token för CloudKit
    }

    // Körs när appen misslyckades att registrera sig för fjärrnotiser
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Denna metod anropas när en push-notis tas emot, OAVSETT om appen är i förgrunden, bakgrunden eller stängd (om den startas pga notisen)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("AppDelegate: Received remote notification (raw): \(userInfo)")

        // Försök skapa en CloudKit-notis från mottagen data
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            print("AppDelegate: Notification is from CloudKit.")

            // Anropa din CloudKit-hanterare
            CloudKitFoodDataStore.shared.handleNotification()

            // Meddela systemet att ny data har hämtats (eller kommer att hämtas)
            completionHandler(.newData)
         } else {
             print("AppDelegate: Notification is NOT from CloudKit.")
             // Detta var en annan typ av push-notis
             completionHandler(.noData)
         }
    }

    // MARK: - UNUserNotificationCenterDelegate (Valfritt men bra för felsökning)

    // Anropas när en notis tas emot MEDAN appen är i förgrunden
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("AppDelegate: Will present notification while app is active.")
        // För tysta CloudKit-notiser vill vi oftast inte visa något för användaren
        // Om du *har* andra typer av notiser kan du anpassa detta.
        // Kontrollera om det är en CloudKit-notis igen för säkerhets skull
        if CKNotification(fromRemoteNotificationDictionary: notification.request.content.userInfo) != nil {
            // Det är en CloudKit-notis, vi hanterade den redan i didReceiveRemoteNotification
            // Visa inget extra för användaren.
             print("AppDelegate: It's a silent CloudKit notification, suppressing presentation.")
            completionHandler([]) // Tom array betyder "visa inget"
        } else {
            // Annan typ av notis, visa den som vanligt (t.ex. banner, ljud)
             print("AppDelegate: It's another type of notification, allowing presentation.")
            completionHandler([.banner, .list, .sound]) // Anpassa efter behov
        }
    }

    // Anropas när användaren interagerar med en notis (klickar på den)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("AppDelegate: User interacted with notification.")
        // Här kan du hantera vad som ska hända när användaren klickar på en notis
        // (t.ex. navigera till en specifik vy). För tysta CloudKit-notiser behövs oftast inget här.
        completionHandler()
    }
}