//
//  HomeScreen.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 4/10/25.
//

import SwiftUI

struct HomeView: View {
    @Binding var cur_screen: Screen
    @State var isHideCompletedReminders: Bool = false
    let firestoreManager: FirestoreManager
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack {
            // Top bar
            HStack {
                if firestoreManager.isCaretakerViewingSenior {
                    Button(action: {
                        // Update the screen enum
                        cur_screen = .CaretakerHomeScreen
                        firestoreManager.isCaretakerViewingSenior = false
                        // Dismiss any NavigationLink stack
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to Seniors")
                                .fontWeight(.semibold)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    SettingsExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
                }

                Spacer()

                CreateReminderExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            // Welcome & today's date
            WelcomeExperience()

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
