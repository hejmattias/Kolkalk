// Kolkalk/AppDelegate.swift

import UIKit
import CloudKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - CloudKit Subscription Identifiers
    private struct SubscriptionID {
        static let foodItem = "fooditem-changes-subscription"
        static let container = "container-changes-subscription"
    }

    // MARK: - Debug Logging
    private func debugLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }

    // MARK: - UIApplicationDelegate

    /// Called after the app has launched.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        debugLog("AppDelegate: Application finished launching and registered for remote notifications.")
        return true
    }

    /// Called when registration for remote notifications succeeds.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { String(format: "%02.2hhx", $0) }
        let token = tokenParts.joined()
        debugLog("AppDelegate: Successfully registered for remote notifications with Device Token: \(token)")
    }

    /// Called when registration for remote notifications fails.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        debugLog("AppDelegate Error: Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Handles incoming remote notifications, including silent CloudKit pushes.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        debugLog("AppDelegate: Received remote notification (raw): \(userInfo)")

        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            debugLog("AppDelegate: Notification is NOT from CloudKit.")
            completionHandler(.noData)
            return
        }
        debugLog("AppDelegate: Notification is from CloudKit.")

        if let queryNotification = notification as? CKQueryNotification {
            let subscriptionID = queryNotification.subscriptionID
            debugLog("AppDelegate: Received Query Notification with SubscriptionID: \(subscriptionID ?? "N/A")")

            var dataChanged = false

            switch subscriptionID {
            case SubscriptionID.foodItem:
                debugLog("AppDelegate: Handling FoodItem change notification...")
                DispatchQueue.main.async {
                    CloudKitFoodDataStore.shared.handleNotification()
                }
                dataChanged = true
            case SubscriptionID.container:
                debugLog("AppDelegate: Handling Container change notification...")
                DispatchQueue.main.async {
                    CloudKitContainerDataStore.shared.handleContainerNotification()
                }
                dataChanged = true
            default:
                debugLog("AppDelegate Warning: Notification received for unknown or unhandled subscription ID: \(subscriptionID ?? "N/A")")
            }

            completionHandler(dataChanged ? .newData : .noData)
        } else {
            debugLog("AppDelegate: Received a non-query CKNotification type: \(type(of: notification))")
            completionHandler(.noData)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification arrives while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        debugLog("AppDelegate: Notification will present while app is active.")

        if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
            debugLog("AppDelegate: It's a silent CloudKit notification, suppressing presentation.")
            completionHandler([])
        } else {
            debugLog("AppDelegate: It's another type of notification, allowing standard presentation.")
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .list, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
    }

    /// Called when the user interacts with a visible notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        debugLog("AppDelegate: User interacted with notification.")

        // Här kan du lägga till logik för att hantera interaktioner med notiser.
        completionHandler()
    }
}
