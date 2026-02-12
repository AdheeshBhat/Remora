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
    // Listener for Firestore reminders collection
    @State private var reminderListener: ListenerRegistration?

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
                // When app comes to foreground:
                // 1. Refresh any forever-repeating alarms
                NotificationManager.shared.refreshForeverAlarms()
                // 2. Re-schedule all notifications for the current user
                rescheduleAllNotificationsForUser() // <- this is critical to ensure local notifications stay accurate
            }
        }
    }
    
    private func setupAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [self] _, user in
            if user != nil {
                // User logged in
                let loader = FirestoreManager()
                appearance.loadFromFirebase(firestoreManager: loader) // Load appearance preferences from Firestore
                rescheduleAllNotificationsForUser() // Re-schedule notifications after login
                startListeningForNewReminders() // Set up Firestore listener for new reminders
            } else {
                // User logged out
                DispatchQueue.main.async {
                    self.appearance.useLightMode = true // Reset to default appearance
                    self.appearance.defaultToCalendarView = false
                }
                reminderListener?.remove()  // Stop listening for reminders
                reminderListener = nil
            }
        }
    }

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
        // Ensures app can handle notifications while in foreground or background
    }
    
    private func setupPushNotifications() {
        PushNotificationManager.shared.registerForPushNotifications()
        // Requests permission from user and registers for FCM
    }
    
    private func startListeningForNewReminders() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        // Listen for changes in the reminders subcollection for current user
        reminderListener = db.collection("users")
            .document(uid)
            .collection("reminders")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else { return }
                
                for change in snapshot.documentChanges {
                    if change.type == .added  || change.type == .modified { // Only care about newly added reminders or edited
                        print("LISTENER TRIGGERED")
                        let data = change.document.data()
                        let documentID = change.document.documentID
                        
                        // Extract key fields from the reminder document
                        guard let timestamp = data["date"] as? Timestamp,
                              let title = data["title"] as? String,
                              let description = data["description"] as? String else { continue }
                        
                        let isComplete = data["isComplete"] as? Bool ?? false
                        if isComplete {
                            // Skip completed reminders, cancel existing notification
                            cancelAlarm(reminderID: documentID)
                            continue
                        }
                        
                        let caretakerAlertDelay = data["caretakerAlertDelay"] as? TimeInterval ?? 1800
                        let repeatSettings = data["repeatSettings"] as? [String: Any]
                        let repeatType = repeatSettings?["repeat_type"] as? String ?? "None"
                        let repeatUntil = repeatSettings?["repeat_until_date"] as? String ?? "Forever"
                        
                        var customRepeat: CustomRepeatType? = nil
                        if let repeatIntervals = repeatSettings?["repeatIntervals"] as? [String: Any],
                           let days = repeatIntervals["days"] as? String {
                            customRepeat = CustomRepeatType(days: days)
                        }
                        
                        // Determine if this device is caretaker or senior
                        FirestoreManager().checkIfCaretaker { isCaretaker in
                            // Load user's preferred sound type from Firestore
                            FirestoreManager().loadUserSettings(field: "selectedSound") { soundValue in
                                let soundType = (soundValue as? String) ?? "Chord"

                                if isCaretaker {
                                    // CARETAKER DEVICE SCHEDULING
                                    let seniorName = data["author"] as? String ?? "Senior"

                                    setAlarm(
                                        dateAndTime: timestamp.dateValue(),
                                        title: title,
                                        description: description,
                                        repeat_type: repeatType,
                                        repeat_until_date: repeatUntil,
                                        repeatIntervals: customRepeat,
                                        reminderID: documentID,
                                        soundType: soundType,
                                        caretakerAlertDelay: caretakerAlertDelay,
                                        isCaretakerNotification: true,              // marks it as caretaker alert
                                        seniorName: seniorName
                                    )

                                } else {
                                    // SENIOR DEVICE SCHEDULING
                                    setAlarm(
                                        dateAndTime: timestamp.dateValue(),
                                        title: title,
                                        description: description,
                                        repeat_type: repeatType,
                                        repeat_until_date: repeatUntil,
                                        repeatIntervals: customRepeat,
                                        reminderID: documentID,
                                        soundType: soundType,
                                        caretakerAlertDelay: caretakerAlertDelay
                                    )
                                }
                            }
                        }
                    }
                    if change.type == .removed {
                        cancelAlarm(reminderID: change.document.documentID)
                    }
                }
            }
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

