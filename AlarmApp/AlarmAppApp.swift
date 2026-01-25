//
//  AlarmAppApp.swift
//  AlarmApp
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@main
struct AlarmAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appearance: AppearanceModel
    @State private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        FirebaseApp.configure()
        
    

        // ✅ Create the model FIRST
        let appearanceModel = AppearanceModel()
        _appearance = StateObject(wrappedValue: appearanceModel)
        
        setupNotificationDelegate()
        setupPushNotifications()
        // ✅ Use the model directly (NOT self)
        authHandle = Auth.auth().addStateDidChangeListener { _, user in
            if user != nil {
                let loader = FirestoreManager()
                appearanceModel.loadFromFirebase(firestoreManager: loader)
            } else {
                DispatchQueue.main.async {
                    appearanceModel.useLightMode = true
                    appearanceModel.defaultToCalendarView = false
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearance)
                .preferredColorScheme(
                    appearance.useLightMode ? .light : .dark
                )
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NotificationManager.shared.refreshForeverAlarms()
            }
        }
    }

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
    }
    
    private func setupPushNotifications() {
        PushNotificationManager.shared.registerForPushNotifications()
    }
}

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationManager.shared.handleNotificationResponse(response: response)
        completionHandler()
    }
}
