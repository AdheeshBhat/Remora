//
//  PushNotificationManager.swift
//  AlarmApp
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
    
    // Remove all token fetching calls on init; use AppDelegate callback only
    func storeFCMToken(for userUID: String) {
        // Optional manual store
        Messaging.messaging().token { token, error in
            if let token = token { FirestoreManager().storeFCMToken(token: token, for: userUID) }
        }
    }
    
    func sendPushNotification(to userUID: String, title: String, body: String, reminderID: String) {
        FirestoreManager().getFCMToken(for: userUID) { token in
            guard let token = token else { return }
            print("Would send push to token \(token): \(title)")
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
        }
    }
}
