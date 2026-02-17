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
    // Observes the current lifecycle state of the app (active, background, inactive)
    @Environment(\.scenePhase) private var scenePhase
    // Global appearance settings (dark/light mode, calendar defaults)
    @StateObject private var appearance: AppearanceModel
    // Firebase Auth listener handle to detach listener when needed
    @State private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        FirebaseApp.configure()

        let appearanceModel = AppearanceModel()
        _appearance = StateObject(wrappedValue: appearanceModel)
        
        setupNotificationDelegate() // Assign UNUserNotificationCenter delegate
        setupPushNotifications()    // Request push notifications permission & register
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearance)
                .preferredColorScheme(
                    appearance.useLightMode ? .light : .dark
                )
                .onAppear {
                    setupAuthListener()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("App became active")
            }
        }
    }
    
    private func setupAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [self] _, user in
            if user != nil {
                let loader = FirestoreManager()
                appearance.loadFromFirebase(firestoreManager: loader)
            } else {
                DispatchQueue.main.async {
                    self.appearance.useLightMode = true
                    self.appearance.defaultToCalendarView = false
                }
            }
        }
    }

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
        // Ensures app can handle notifications while in foreground or background
    }
    
    private func setupPushNotifications() {
        PushNotificationManager.shared.registerForPushNotifications()
    }
}

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    // Called when a notification is delivered while the app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationManager.shared.handleNotificationResponse(response: response)
        completionHandler()
    }
}

