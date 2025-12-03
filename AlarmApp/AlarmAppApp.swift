//
//  AlarmAppApp.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 4/21/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UserNotifications

@main
struct AlarmAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var appearance = AppearanceModel()
    
    init() {
        FirebaseApp.configure()
        setupNotificationDelegate()
        
//        let loader = FirestoreManager()
//        appearance.loadFromFirebase(firestoreManager: loader)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appearance)
                .task {
                    let loader = FirestoreManager()
                    appearance.loadFromFirebase(firestoreManager: loader)
                }
                .preferredColorScheme(appearance.useLightMode ? .light : .dark)
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
}

class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler:
                                @escaping () -> Void) {
        NotificationManager.shared.handleNotificationResponse(response: response)
        completionHandler()
    }
}
