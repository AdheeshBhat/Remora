//
//  PushNotificationManager.swift
//  AlarmApp
//
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
        
        let currentUID = FirestoreManager().activeUserUID
        if !currentUID.isEmpty {
            FirestoreManager().storeFCMToken(token: fcmToken, for: currentUID)
        } else {
            print("No active user UID found; skipping FCM token storage.")
        }
    }
}

