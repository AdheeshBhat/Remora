//
//  CreateReminderScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 5/28/25.
//

import SwiftUI

struct CreateReminderScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var cur_screen: Screen
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    //GET RID OF USERID COMPELTELY
    @State private var userID: Int = 1
    @State private var repeat_setting: String = "None"
    @State private var repeatUntil: String = "Forever"
    @State private var customPatterns: Set<String> = []
    @State private var priority: String = "Low"
    @State private var isComplete: Bool = false
    @State private var author: String = ""
    @State private var isLocked: Bool = false
    @State private var showReminderNameAlert: Bool = false
    @State var selectedSound: String = "Chord"
    let firestoreManager: FirestoreManager
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Type Reminder Name...", text: $title)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .foregroundColor(.primary)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Add your description here!")
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            }
                            TextEditor(text: $description)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                                .scrollContentBackground(.hidden)
                        }
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    VStack(spacing: 16) {
                        NavigationLink(
                            destination: DateSelectorScreen(
                                reminderTitle: title,
                                selectedDate: $date,
                                cur_screen: $cur_screen,
                                firestoreManager: firestoreManager
                            )
                        ) {
                            HStack {
                                Text(formattedDate)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(height: 150)
                            .clipped()
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    HStack {
                        Image(systemName: "arrow.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Repeat")
                            .foregroundColor(.primary)
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        NavigationLink(
                            destination: RepeatSettingsFlow(
                                cur_screen: $cur_screen,
                                title: title,
                                repeatSetting: $repeat_setting,
                                repeatUntil: $repeatUntil,
                                customPatterns: $customPatterns,
                                firestoreManager: firestoreManager
                            )
                        ) {
                            HStack {
                                Text(repeat_setting)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(title.isEmpty)
                        .simultaneousGesture(TapGesture().onEnded {
                            if title.isEmpty {
                                showReminderNameAlert = true
                            }
                        })
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.blue)
                        Text("Priority")
                            .foregroundColor(.primary)
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        NavigationLink(
                            destination: PriorityFlow(
                                cur_screen: $cur_screen,
                                title: title,
                                priority: $priority,
                                isLocked: $isLocked,
                                firestoreManager: firestoreManager)
                        ) {
                            HStack {
                                Text(priority)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(title.isEmpty)
                        .simultaneousGesture(TapGesture().onEnded {
                            if title.isEmpty {
                                showReminderNameAlert = true
                            }
                        })
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    Button(action: {
                        if title.isEmpty {
                            showReminderNameAlert = true
                        } else {
                            let customRepeatType = customPatterns.isEmpty ? nil : CustomRepeatType(days: customPatterns.joined(separator: ","))
                            let reminder = ReminderData(
                                ID: Int.random(in: 1000...9999),
                                date: date,
                                title: title,
                                description: description,
                                repeatSettings: RepeatSettings(repeat_type: repeat_setting, repeat_until_date: repeatUntil, repeatIntervals: customRepeatType),
                                priority: priority,
                                isComplete: isComplete,
                                author: author,
                                isLocked: isLocked
                            )
                            //let uniqueID = Date.now
                            let reminderID = getExactStringFromCurrentDate()
                            firestoreManager.setReminder(reminderID: reminderID, reminder: reminder)
                            presentationMode.wrappedValue.dismiss()
                            setAlarm(
                                dateAndTime: date,
                                title: title,
                                description: description,
                                repeat_type: reminder.repeatSettings.repeat_type,
                                repeat_until_date: reminder.repeatSettings.repeat_until_date,
                                repeatIntervals: reminder.repeatSettings.repeatIntervals,
                                reminderID: reminderID,
                                soundType: selectedSound
                            )
                        }
                    }) {
                        Text("Save New Reminder")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
        }
        .background(Color(.systemBackground))
        .alert("Please type the reminder name first.", isPresented: $showReminderNameAlert) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            cur_screen = .CreateReminderScreen
        }
    }
}


