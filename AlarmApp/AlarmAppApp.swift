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
    @State private var reminderListener: ListenerRegistration?

    init() {
        FirebaseApp.configure()

        let appearanceModel = AppearanceModel()
        _appearance = StateObject(wrappedValue: appearanceModel)
        
        setupNotificationDelegate()
        setupPushNotifications()
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
                NotificationManager.shared.refreshForeverAlarms()
                rescheduleAllNotificationsForUser()
            }
        }
    }
    
    private func setupAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [self] _, user in
            if user != nil {
                let loader = FirestoreManager()
                appearance.loadFromFirebase(firestoreManager: loader)
                rescheduleAllNotificationsForUser()
                startListeningForNewReminders()
            } else {
                DispatchQueue.main.async {
                    self.appearance.useLightMode = true
                    self.appearance.defaultToCalendarView = false
                }
                reminderListener?.remove()
                reminderListener = nil
            }
        }
    }

    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
    }
    
    private func setupPushNotifications() {
        PushNotificationManager.shared.registerForPushNotifications()
    }
    
    private func startListeningForNewReminders() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        reminderListener = db.collection("users")
            .document(uid)
            .collection("reminders")
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else { return }
                
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        let data = change.document.data()
                        let documentID = change.document.documentID
                        
                        guard let timestamp = data["date"] as? Timestamp,
                              let title = data["title"] as? String,
                              let description = data["description"] as? String else { continue }
                        
                        let isComplete = data["isComplete"] as? Bool ?? false
                        if isComplete { continue }
                        
                        let caretakerAlertDelay = data["caretakerAlertDelay"] as? TimeInterval ?? 1800
                        let repeatSettings = data["repeatSettings"] as? [String: Any]
                        let repeatType = repeatSettings?["repeat_type"] as? String ?? "None"
                        let repeatUntil = repeatSettings?["repeat_until_date"] as? String ?? "Forever"
                        
                        var customRepeat: CustomRepeatType? = nil
                        if let repeatIntervals = repeatSettings?["repeatIntervals"] as? [String: Any],
                           let days = repeatIntervals["days"] as? String {
                            customRepeat = CustomRepeatType(days: days)
                        }
                        
                        FirestoreManager().checkIfCaretaker { isCaretaker in
                            FirestoreManager().loadUserSettings(field: "selectedSound") { soundValue in
                                let soundType = (soundValue as? String) ?? "Chord"

                                if isCaretaker {
                                    // 👇 CARETAKER DEVICE SCHEDULING
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
                                        isCaretakerNotification: true,
                                        seniorName: seniorName
                                    )

                                } else {
                                    // 👇 SENIOR DEVICE SCHEDULING
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
                }
            }
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

