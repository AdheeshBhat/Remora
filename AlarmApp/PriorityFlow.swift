//
//  PriorityFlow.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/8/25.
//

import SwiftUI

struct PriorityFlow: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    @Binding var cur_screen: Screen
    
    var title: String
    @Binding var priority: String
    @State private var localPriority: String
    @Binding var isLocked: Bool
    @State private var localIsLocked: Bool
    let firestoreManager: FirestoreManager
    
    

    init(cur_screen: Binding<Screen>, title: String, priority: Binding<String>, isLocked: Binding<Bool>, firestoreManager: FirestoreManager) {
        self._cur_screen = cur_screen
        self.title = title
        self._priority = priority
        self._isLocked = isLocked
        // Initialize local state variables
        self._localPriority = State(initialValue: priority.wrappedValue)
        self._localIsLocked = State(initialValue: isLocked.wrappedValue)
        self.firestoreManager = firestoreManager
    }

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()

                    VStack {
                        HStack {
                            Text("Priority")
                                .foregroundColor(.primary)
                                .font(.headline)
                                .fontWeight(.medium)
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.primary)
                                .padding(.leading, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 0) {
                        Button(action: {
                            localPriority = "Low"
                        }) {
                            HStack {
                                Text("Low")
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .padding(.leading, 16)
                                Spacer()
                                if localPriority == "Low" {
                                    Image(systemName: "checkmark")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                        .padding(.trailing, 16)
                                }
                            }
                            .padding(.vertical, 16)
                        }

                        Divider()
                            .background(Color.blue.opacity(0.3))
                            .padding(.horizontal, 16)

                        Button(action: {
                            localPriority = "High"
                        }) {
                            HStack {
                                Text("High")
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .padding(.leading, 16)
                                Spacer()
                                if localPriority == "High" {
                                    Image(systemName: "checkmark")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                        .padding(.trailing, 16)
                                }
                            }
                            .padding(.vertical, 16)
                        }
                    }
                    .background(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)

                    if localPriority == "Low" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You :").bold()
                            Text("You will be sent a notification.")
                                .padding(.vertical)
                                .foregroundColor(.secondary)
                            Text("Caretaker :").bold()
                            Text("Your caretaker will be sent a notification after 10 minutes if the reminder is not turned off.")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top)
                    } else if localPriority == "High" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You :").bold()
                            Text("Your alarm will ring.")
                                .padding(.vertical)
                                .foregroundColor(.secondary)
                            Text("Caretaker :").bold()
                            Text("Your caretaker will be called after 10 minutes if the alarm is not turned off.")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top)
                    }

                    Button(action: {
                        localIsLocked.toggle()
                    }) {
                        HStack {
                            Text(localIsLocked ? "Locked Reminder" : "Unlocked Reminder")
                                .foregroundColor(.primary)
                                .font(.headline)
                                .fontWeight(.medium)
                                .padding(.leading, 16)
                            Spacer()
                            Image(systemName: localIsLocked ? "lock.fill" : "lock.open.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .padding(.trailing, 16)
                        }
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.top)

                    Text(localIsLocked ? "You will not be able to edit this reminder." : "You will be able to edit this reminder.")
                        .padding(.top)
                        .foregroundColor(.secondary)

                    Button(action: {
                        priority = localPriority
                        isLocked = localIsLocked
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(.green)
                            .cornerRadius(12)
                    }
                    .padding(.top)

                    Spacer(minLength: 20)
                }
                .padding()
            }

            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager).environmentObject(preloadedReminders)
        }
        .onAppear {
            localPriority = priority
            localIsLocked = isLocked
        }
    }
}


