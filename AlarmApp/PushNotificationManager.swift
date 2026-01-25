//
//  PushNotificationManager.swift
//  AlarmApp
//
//  Created by AI Assistant
//

import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit

class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    override init() {
        super.init()
        Messaging.messaging().delegate = self
    }
    
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func storeFCMToken(for userUID: String) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("FCM registration token: \(token)")
                // Store token in Firestore for this user
                FirestoreManager().storeFCMToken(token: token, for: userUID)
            }
        }
    }
}

extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("Firebase registration token: \(fcmToken)")
        
        // Store the token for the current user
        let currentUID = FirestoreManager().activeUserUID
        if !currentUID.isEmpty {
            FirestoreManager().storeFCMToken(token: fcmToken, for: currentUID)
        } else {
            // Optionally log when there's no active user
            print("No active user UID found; skipping FCM token storage.")
        }
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        completionHandler()
    }
}
