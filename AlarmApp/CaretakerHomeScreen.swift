//
//  CaretakerHomeScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 10/14/25.
//

import SwiftUI

struct CaretakerHomeView: View {
    @Binding var cur_screen: Screen
    let firestoreManager: FirestoreManager
    @State private var seniors: [String] = []
    @State private var showingAddSenior = false
    @State private var selectedSeniorUID: String? = nil
    @State private var displayedName: String = ""
    @State private var showingMissedDashboard = false

    var body: some View {
        VStack {
            // Top bar settings button and "add senior" button
            HStack {
                SettingsExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)

                Button(action: {
                    showingMissedDashboard = true
                }) {
                    Image(systemName: "bell.badge")
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.7))
                }
                .sheet(isPresented: $showingMissedDashboard) {
                    MissedRemindersView(firestoreManager: firestoreManager)
                }

                Spacer()
                Button(action: {
                    showingAddSenior = true
                }) {
                    Text("Add Senior")
                        .fontWeight(.semibold)
                        .padding(8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .sheet(isPresented: $showingAddSenior) {
                    AddSeniorView(
                        firestoreManager: firestoreManager,
                        onSuccess: {
                            firestoreManager.fetchLinkedSeniors { names in
                                DispatchQueue.main.async {
                                    self.seniors = names
                                }
                            }
                        }
                    )
                }
                .padding(.trailing)
            }

        
            WelcomeExperience(firestoreManager: firestoreManager, uidToDisplay: firestoreManager.activeUserUID)
            

            // Seniors list or empty message
            if seniors.isEmpty {
                Text("You have no linked seniors yet. Please add a senior to get started!")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                List {
                    ForEach(seniors, id: \.self) { senior in
                        Button(action: {
                            firestoreManager.getUIDFromUsername(username: senior) { uid in
                                guard let uid = uid, !uid.isEmpty else { return }
                                firestoreManager.currentUID = uid
                                DispatchQueue.main.async {
                                    firestoreManager.isCaretakerViewingSenior = true
                                    selectedSeniorUID = uid
                                    displayedName = senior
                                }
                            }
                        }) {
                            HStack {
                                Text(senior)
                                    .font(.headline)
                                Spacer()
                                Menu {
                                    Button(role: .destructive) {
                                        firestoreManager.unlinkSenior(username: senior) { error in
                                            if let error = error {
                                                print("Error unlinking senior: \(error.localizedDescription)")
                                            } else {
                                                firestoreManager.fetchLinkedSeniors { names in
                                                    DispatchQueue.main.async {
                                                        self.seniors = names
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        Text("Unlink")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .rotationEffect(.degrees(90))
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            cur_screen = .CaretakerHomeScreen
            firestoreManager.fetchLinkedSeniors { names in
                DispatchQueue.main.async {
                    self.seniors = names
                }
            }
        }
        // Navigate to senior's version of the app (HomeView)
        .background(
            NavigationLink(
                destination: Group {
                    if selectedSeniorUID != nil {
                        HomeView(
                            cur_screen: $cur_screen,
                            firestoreManager: firestoreManager
                        )
                    } else {
                        EmptyView()
                    }
                },
                isActive: Binding(
                    get: { selectedSeniorUID != nil },
                    set: { active in
                        if !active { selectedSeniorUID = nil }
                    }
                )
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
}


struct AddSeniorView: View {
    @Environment(\.dismiss) var dismiss
    let firestoreManager: FirestoreManager
    var onSuccess: (() -> Void)?
    @State private var username: String = ""
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Senior")
                .font(.title)
                .fontWeight(.bold)

            TextField("Enter Senior's Username", text: $username)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .autocapitalization(.none)

            Button("Link Senior") {
                addSenior()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer()
        }
        .padding()
    }

    private func addSenior() {
        firestoreManager.getUIDFromUsername(username: username) { uid in
            guard let uid = uid, !uid.isEmpty else {
                statusMessage = "No user found with that username."
                return
            }

            firestoreManager.linkSeniorToCaretaker(seniorUID: uid, seniorUsername: username) { error in
                if let error = error {
                    statusMessage = "Error linking senior: \(error.localizedDescription)"
                } else {
                    statusMessage = "Successfully linked senior!"
                    onSuccess?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MissedRemindersView: View {
    let firestoreManager: FirestoreManager
    @State private var missedReminders: [MissedReminder] = []

    var body: some View {
        NavigationView {
            List {
                if missedReminders.isEmpty {
                    Text("No missed reminders.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(missedReminders) { reminder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.headline)

                            Text("Senior: \(reminder.seniorName)")
                                .font(.subheadline)

                            Text(reminder.dateString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Missed Reminders")
            .onAppear {
                loadMissedReminders()
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadMissedReminders() {
        firestoreManager.getLinkedSeniorUIDs { seniorUIDs in
            // Build UID -> firstName map for better UI
            var nameMap: [String: String] = [:]
            let nameGroup = DispatchGroup()

            for uid in seniorUIDs {
                nameGroup.enter()
                firestoreManager.getUserFirstName(forUID: uid) { name in
                    nameMap[uid] = name ?? "Unknown"
                    nameGroup.leave()
                }
            }

            nameGroup.notify(queue: .main) {
                firestoreManager.getRemindersForMultipleUsers(uids: seniorUIDs) { results in

                    var newMissed: [MissedReminder] = []
                    let now = Date()

                    for (uid, reminders) in results {
                        for (_, reminder) in reminders {
                            let scheduledDate = reminder.date
                            let delay = reminder.caretakerAlertDelay
                            let deadline = scheduledDate.addingTimeInterval(delay)

                            if deadline < now {
                                if reminder.repeatSettings.repeat_type == "None" {
                                    if !reminder.isComplete {
                                        newMissed.append(
                                            MissedReminder(
                                                title: reminder.title,
                                                seniorName: nameMap[uid] ?? "Unknown",
                                                dateString: formatDate(scheduledDate)
                                            )
                                        )
                                    }

                                } else {
                                    let completed = reminder.completedInstances.contains {
                                        Calendar.current.isDate($0, inSameDayAs: scheduledDate)
                                    }
                                    if !completed {
                                        newMissed.append(
                                            MissedReminder(
                                                title: reminder.title,
                                                seniorName: nameMap[uid] ?? "Unknown",
                                                dateString: formatDate(scheduledDate)
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        self.missedReminders = newMissed.sorted {
                            $0.dateString > $1.dateString
                        }
                    }
                }
            }
        }
    }
}

struct MissedReminder: Identifiable {
    let id = UUID()
    let title: String
    let seniorName: String
    let dateString: String
}
