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
import FirebaseAppCheck

@main
struct AlarmAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appearance: AppearanceModel
    @State private var authHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        let appearanceModel = AppearanceModel()
        _appearance = StateObject(wrappedValue: appearanceModel)
        setupNotificationDelegate() // Ensure delegate assigned early
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearance)
                .preferredColorScheme(appearance.useLightMode ? .light : .dark)
                .onAppear {
                    setupAuthListener()
                    // Only register for push notifications after user login
                    if Auth.auth().currentUser != nil {
                        PushNotificationManager.shared.registerForPushNotifications()
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { print("App became active") }
        }
    }
    
    private func setupAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { _, user in
            if user != nil {
                PushNotificationManager.shared.registerForPushNotifications()
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
    }
}

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
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
