////
////  EditReminderScreen.swift
////  AlarmApp
////
////  Created by Adheesh Bhat on 6/30/25.
////

import SwiftUI
import FirebaseFirestore

struct EditReminderScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var cur_screen: Screen
    @State var showReminderNameAlert: Bool = false
    @State var localTitle: String = ""
    @State var localDescription: String = ""
    @State var localEditScreenPriority: String = "Medium"
    @State var localEditScreenIsLocked: Bool = false
    @State var localEditScreenRepeatSetting: String = "None"
    @State var localEditScreenRepeatUntil: String = "Forever"
    @State var localCustomPatterns: Set<String> = []
    @State private var localDate: Date = Date()
    @State private var isComplete: Bool = false
    @State var selectedSound: String = "Chord"
    @State var hasLoadedFromFirebase: Bool = false
    let firestoreManager: FirestoreManager
    let reminderID: String
    let onUpdate: (() -> Void)?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: localDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Type Reminder Name...", text: $localTitle)
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
                            if localDescription.isEmpty {
                                Text("Add your description here!")
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            }
                            TextEditor(text: $localDescription)
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
                                reminderTitle: localTitle,
                                selectedDate: $localDate,
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
                        
                        DatePicker("", selection: $localDate, displayedComponents: [.hourAndMinute])
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
                                title: localTitle,
                                repeatSetting: $localEditScreenRepeatSetting,
                                repeatUntil: $localEditScreenRepeatUntil,
                                customPatterns: $localCustomPatterns,
                                firestoreManager: firestoreManager
                            )
                        ) {
                            HStack {
                                Text(localEditScreenRepeatSetting)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(localTitle.isEmpty)
                        .simultaneousGesture(TapGesture().onEnded {
                            if localTitle.isEmpty {
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
                            destination: PriorityFlow(cur_screen: $cur_screen, title: localTitle, priority: $localEditScreenPriority, isLocked: $localEditScreenIsLocked, firestoreManager: firestoreManager)
                        ) {
                            HStack {
                                Text(localEditScreenPriority)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(localTitle.isEmpty)
                        .simultaneousGesture(TapGesture().onEnded {
                            if localTitle.isEmpty {
                                showReminderNameAlert = true
                            }
                        })
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    //SAVE BUTTON
                    Button(action: {
                        let repeatIntervalsDict: [String: Any]? = localCustomPatterns.isEmpty ? nil : ["days": localCustomPatterns.joined(separator: ",")]
                        firestoreManager.updateReminderFields(
                            dateCreated: reminderID,
                            fields: [
                                "title": localTitle,
                                "description": localDescription,
                                "priority": localEditScreenPriority,
                                "isLocked": localEditScreenIsLocked,
                                "repeatSettings.repeat_type": localEditScreenRepeatSetting,
                                "repeatSettings.repeat_until_date": localEditScreenRepeatUntil,
                                "repeatSettings.repeatIntervals": repeatIntervalsDict,
                                "date": Timestamp(date: localDate)]
                        ) { success in
                            if success {
                                DispatchQueue.main.async {
                                    let customRepeatType = localCustomPatterns.isEmpty ? nil : CustomRepeatType(days: localCustomPatterns.joined(separator: ","))
                                    
                                    // Cancel the old notification and set a new one
                                    cancelAlarm(reminderID: reminderID)
                                    if !isComplete {
                                        setAlarm(
                                            dateAndTime: localDate,
                                            title: localTitle,
                                            description: localDescription,
                                            repeat_type: localEditScreenRepeatSetting,
                                            repeat_until_date: localEditScreenRepeatUntil,
                                            repeatIntervals: customRepeatType,
                                            reminderID: reminderID,
                                            soundType: selectedSound
                                        )
                                    }
                                    
                                    onUpdate?()
                                }
                            }
                        }
                        
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Save Changes")
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
            cur_screen = .EditScreen
            // Load fresh reminder data from Firebase
            firestoreManager.getReminder(dateCreated: reminderID) { document in
                guard let data = document?.data() else { return }
                
                if !hasLoadedFromFirebase {
                    hasLoadedFromFirebase = true
                    if let timestamp = data["date"] as? Timestamp {
                        localDate = timestamp.dateValue()
                    }
                    if let title = data["title"] as? String {
                        localTitle = title
                    }
                    if let description = data["description"] as? String {
                        localDescription = description
                    }
                    if let priority = data["priority"] as? String {
                        localEditScreenPriority = priority
                    }
                    if let isLocked = data["isLocked"] as? Bool {
                        localEditScreenIsLocked = isLocked
                    }
                    if let repeatSettings = data["repeatSettings"] as? [String: Any] {
                        if let repeatType = repeatSettings["repeat_type"] as? String {
                            localEditScreenRepeatSetting = repeatType
                        }
                        if let repeatUntil = repeatSettings["repeat_until_date"] as? String {
                            localEditScreenRepeatUntil = repeatUntil
                        }
                        if let repeatIntervals = repeatSettings["repeatIntervals"] as? [String: Any],
                           let days = repeatIntervals["days"] as? String {
                            localCustomPatterns = Set(days.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
                        }
                    }
                    // Update completion status
                    if let complete = data["isComplete"] as? Bool {
                        isComplete = complete
                    }
                }
                
            }
        }

    }
}


