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
    @State public var cur_screen: Screen = .HomeScreen
    @State private var isCaretaker: Bool = false
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    let firestoreManager = FirestoreManager()
    
    var body: some View {

        NavigationStack {
            Group {
                if Auth.auth().currentUser == nil {
                    LoginScreen(cur_screen: $cur_screen)
                } else if isCaretaker {
                    CaretakerHomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)
                } else {
                    HomeView(cur_screen: $cur_screen, firestoreManager: FirestoreManager())
                }
            }
        }
        
        .onAppear {
            requestNotificationPermission()
            checkUserStatus()
            //viewModel.addTestReminder()
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
