//
//  AppDelegate.swift
//  AlarmApp
//

import UIKit
import Firebase
import FirebaseMessaging
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase once
        FirebaseApp.configure()
        print("Firebase configured in AppDelegate")
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Set APNs token for FCM
        Messaging.messaging().apnsToken = deviceToken
        print("APNS token set: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // Fetch FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM token: \(error)")
            } else if let token = token {
                print("Firebase registration token: \(token)")
                // Store token for active user
                FirestoreManager().storeFCMToken(token: token, for: FirestoreManager().activeUserUID)
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
