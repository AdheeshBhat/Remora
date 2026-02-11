////
////  EditReminderScreen.swift
////  AlarmApp
////
////  Created by Adheesh Bhat on 6/30/25.
////

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EditReminderScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var cur_screen: Screen
    @State var showReminderNameAlert: Bool = false
    @State var localTitle: String = ""
    @State var localDescription: String = ""
    @State var localEditScreenPriority: String = "Low"
    @State var localEditScreenIsLocked: Bool = false
    @State var localEditScreenRepeatSetting: String = "None"
    @State var localEditScreenRepeatUntil: String = "Forever"
    @State var localCustomPatterns: Set<String> = []
    @State private var localDate: Date = Date()
    @State private var isComplete: Bool = false
    @State var selectedSound: String = "Chord"
    @State var hasLoadedFromFirebase: Bool = false
    @State private var caretakerAlertDelay: TimeInterval = 1800
    @State private var reminderOwnerUID: String = ""
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
                    
                    //PRIORITY
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
                    
                    //CARETAKER ALERT SETTINGS
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.blue)
                        Text("Caretaker Alert Delay")
                            .foregroundColor(.primary)
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        NavigationLink(
                            destination: CaretakerAlertSettingsScreen(
                                cur_screen: $cur_screen,
                                title: localTitle,
                                selectedDelay: $caretakerAlertDelay,
                                firestoreManager: firestoreManager,
                                reminderID: reminderID,
                                onDone: nil
                            )
                        ) {
                            HStack {
                                Text(humanReadableDelay(from: caretakerAlertDelay))
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
                                "date": Timestamp(date: localDate),
                                "caretakerAlertDelay": caretakerAlertDelay]
                        ) { success in
                            if success {
                                DispatchQueue.main.async {
                                    // Cancel the old notification and set a new one
                                    cancelAlarm(reminderID: reminderID)
                                    guard !isComplete else { return }

                                    // Reconstruct ReminderData object (mirror CreateReminderScreen)
                                    let customRepeatType = localCustomPatterns.isEmpty
                                        ? nil
                                        : CustomRepeatType(days: localCustomPatterns.joined(separator: ","))

                                    var reminder = ReminderData(
                                        ID: Int.random(in: 1000...9999),
                                        date: localDate,
                                        title: localTitle,
                                        description: localDescription,
                                        repeatSettings: RepeatSettings(
                                            repeat_type: localEditScreenRepeatSetting,
                                            repeat_until_date: localEditScreenRepeatUntil,
                                            repeatIntervals: customRepeatType
                                        ),
                                        priority: localEditScreenPriority,
                                        isComplete: isComplete,
                                        author: "",
                                        isLocked: localEditScreenIsLocked,
                                        caretakerAlertDelay: caretakerAlertDelay
                                    )

                                    let activeUID = firestoreManager.activeUserUID

                                    firestoreManager.checkIfCaretaker { isCaretaker in
                                        if isCaretaker {
                                            // CARETAKER EDITING A SENIOR'S REMINDER
                                            let seniorUID = reminderOwnerUID.isEmpty ? activeUID : reminderOwnerUID

                                            // Rewrite reminder for senior
                                            firestoreManager.setReminder(
                                                reminderID: reminderID,
                                                reminder: reminder,
                                                forUIDs: [seniorUID]
                                            )

                                            // Rewrite reminder for caretaker
                                            firestoreManager.setReminder(
                                                reminderID: reminderID,
                                                reminder: reminder,
                                                forUIDs: [Auth.auth().currentUser?.uid ?? ""]
                                            )

                                            // Schedule caretaker local notification
                                            firestoreManager.loadUserSettings(field: "selectedSound") { soundValue in
                                                let soundType = (soundValue as? String) ?? "Chord"
                                                firestoreManager.getUserFirstName(forUID: seniorUID) { seniorName in
                                                    guard let seniorName = seniorName else { return }

                                                    setAlarm(
                                                        dateAndTime: localDate,
                                                        title: localTitle,
                                                        description: localDescription,
                                                        repeat_type: localEditScreenRepeatSetting,
                                                        repeat_until_date: localEditScreenRepeatUntil,
                                                        repeatIntervals: customRepeatType,
                                                        reminderID: reminderID,
                                                        soundType: soundType,
                                                        caretakerAlertDelay: caretakerAlertDelay,
                                                        isCaretakerNotification: true,
                                                        seniorName: seniorName
                                                    )
                                                }
                                            }

                                        } else {
                                            // SENIOR EDITING THEIR OWN REMINDER

                                            // Rewrite reminder for senior
                                            firestoreManager.setReminder(
                                                reminderID: reminderID,
                                                reminder: reminder,
                                                forUIDs: [activeUID]
                                            )

                                            // Rewrite reminder for all linked caretakers
                                            firestoreManager.getLinkedCaretakersForSenior(seniorUID: activeUID) { caretakerUIDs in
                                                for caretakerUID in caretakerUIDs {
                                                    firestoreManager.setReminder(
                                                        reminderID: reminderID,
                                                        reminder: reminder,
                                                        forUIDs: [caretakerUID]
                                                    )
                                                }
                                            }

                                            // Schedule senior local notification
                                            firestoreManager.loadUserSettings(field: "selectedSound") { soundValue in
                                                let soundType = (soundValue as? String) ?? "Chord"
                                                firestoreManager.getUserFirstName(forUID: activeUID) { seniorName in
                                                    guard let seniorName = seniorName else { return }

                                                    reminder.author = seniorName

                                                    setAlarm(
                                                        dateAndTime: localDate,
                                                        title: localTitle,
                                                        description: localDescription,
                                                        repeat_type: localEditScreenRepeatSetting,
                                                        repeat_until_date: localEditScreenRepeatUntil,
                                                        repeatIntervals: customRepeatType,
                                                        reminderID: reminderID,
                                                        soundType: soundType,
                                                        caretakerAlertDelay: caretakerAlertDelay,
                                                        isCaretakerNotification: false,
                                                        seniorName: seniorName
                                                    )
                                                }
                                            }
                                        }
                                    }

                                    onUpdate?()
                                }
                            } //if statement ending
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
                    if let delay = data["caretakerAlertDelay"] as? TimeInterval {
                        caretakerAlertDelay = delay
                    }
                    // Update completion status
                    if let complete = data["isComplete"] as? Bool {
                        isComplete = complete
                    }
                    // Set reminderOwnerUID from Firestore document
                    if let authorUID = data["authorUID"] as? String {
                        reminderOwnerUID = authorUID
                    } else {
                        reminderOwnerUID = firestoreManager.activeUserUID
                    }
                }
            }
        }

    }
}



// Helper for human readable delay
extension EditReminderScreen {
    func humanReadableDelay(from delay: TimeInterval) -> String {
        let minutes = Int(delay) / 60
        if minutes < 60 {
            return "\(minutes) min" + (minutes == 1 ? "" : "s")
        }
        let hours = Double(minutes) / 60.0
        if hours == floor(hours) {
            let h = Int(hours)
            return "\(h) hr" + (h == 1 ? "" : "s")
        }
        // For non-whole hours, show as "1 hr 30 mins"
        let h = Int(hours)
        let m = minutes % 60
        if m == 0 {
            return "\(h) hr" + (h == 1 ? "" : "s")
        }
        return "\(h) hr" + (h == 1 ? "" : "s") + " \(m) min" + (m == 1 ? "" : "s")
    }
}
