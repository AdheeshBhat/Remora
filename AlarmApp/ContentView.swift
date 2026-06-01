//
//  ContentView.swift
//  Alarm App

//  Created by Adheesh Bhat on 1/9/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth


//create functions for all texts on the screen (ex. one function for "welcome and date")
enum Screen {
    case HomeScreen, RemindersScreen, NotificationsScreen, EditScreen, CreateReminderScreen, CalendarScreen, SettingsScreen, NotificationSettings, NotificationAlertSounds, CaretakerHomeScreen
}


struct ContentView: View {
    @Environment(\.presentationMode) private var
        presentationMode: Binding<PresentationMode>
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    @State public var cur_screen: Screen = .HomeScreen
    @State private var isCaretaker: Bool? = nil
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    let firestoreManager = FirestoreManager()
    
    var body: some View {

        NavigationStack {
            Group {
                if Auth.auth().currentUser == nil {
                    // Not signed in
                    LoginScreen(cur_screen: $cur_screen)
                } else if let isCaretaker = isCaretaker {
                    // Signed in and we know the role
                    if isCaretaker {
                        CaretakerHomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)
                            .environmentObject(preloadedReminders)
                    } else {
                        HomeView(cur_screen: $cur_screen, firestoreManager: FirestoreManager())
                    }
                } else {
                    // Signed in but still loading caretaker status
                    ProgressView("Loading...")
                }
            }
        }
        .task {
            // Ensure we fetch status when the view appears
            requestNotificationPermission()
            checkUserStatus()
        }
        .alert(item: $notificationManager.openedReminderDetail) { detail in
            Alert(
                title: Text(detail.title),
                message: Text(detail.description.isEmpty ? "No description." : detail.description),
                dismissButton: .default(Text("OK"))
            )
        }
    } //Body ending
    
    private func checkUserStatus() {
        guard Auth.auth().currentUser != nil else {
            return
        }

        firestoreManager.checkIfCaretaker { result in
            DispatchQueue.main.async {
                self.isCaretaker = result
            }
        }
    }
} //Content View ending

#Preview {
    ContentView()
}
