//
//  HomeScreen.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 4/10/25.
//

import SwiftUI

struct HomeView: View {
    @Binding var cur_screen: Screen
    @AppStorage("hideCompletedReminders") var isHideCompletedReminders: Bool = false
    let firestoreManager: FirestoreManager
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            // Top bar
            HStack {
                if firestoreManager.isCaretakerViewingSenior {
                    //BACK TO SENIORS BUTTON
                    NavigationLink(
                        destination: CaretakerHomeView(
                            cur_screen: $cur_screen,
                            firestoreManager: firestoreManager
                        )
                    ) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to Seniors")
                                .fontWeight(.semibold)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        cur_screen = .CaretakerHomeScreen
                        firestoreManager.isCaretakerViewingSenior = false
                    })
                } else {
                    SettingsExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
                }

                Spacer()

                CreateReminderExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            // Welcome & today's date
            if firestoreManager.isCaretakerViewingSenior, let seniorUID = firestoreManager.currentUID {
                // Show the senior's name when caretaker is viewing their account
                WelcomeExperience(firestoreManager: firestoreManager, uidToDisplay: seniorUID)
            } else {
                // Show caretaker's own name normally
                WelcomeExperience(firestoreManager: firestoreManager, uidToDisplay: firestoreManager.activeUserUID)
            }
            
            
            // Today's reminders
            TodayRemindersExperience(
                cur_screen: $cur_screen,
                isHideCompletedReminders: isHideCompletedReminders,
                firestoreManager: firestoreManager
            )
            .padding(.bottom)

            // Toggle for completed reminders
            VStack {
                Toggle("Hide Completed Reminders", isOn: $isHideCompletedReminders)
                    .font(.headline)
                    .fontWeight(.medium)
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }

            Spacer()

            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
        }
        
        .onAppear {
            cur_screen = .HomeScreen
            
        }
    }
        
}
