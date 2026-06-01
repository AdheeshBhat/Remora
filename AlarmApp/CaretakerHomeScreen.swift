//
//  CaretakerHomeScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 10/14/25.
//


import SwiftUI

struct LinkedSeniorSummary: Identifiable, Hashable {
    let uid: String
    let displayName: String
    let username: String
    let isFakeSenior: Bool

    var id: String { uid }
}

struct CaretakerHomeView: View {
    @Binding var cur_screen: Screen
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    let firestoreManager: FirestoreManager
    @State private var seniors: [LinkedSeniorSummary] = []
    @State private var showingAddSenior = false
    @State private var selectedSeniorUID: String? = nil
    @State private var displayedName: String = ""
    @State private var showingMissedDashboard = false
    @State private var hasNewMissedReminders: Bool = false
    @AppStorage("clearedMissedReminders") private var clearedMissedRemindersData: String = ""
    private func getClearedSet() -> Set<String> {
        Set(clearedMissedRemindersData.split(separator: "|").map { String($0) })
    }


    var body: some View {
        VStack {
            // Top bar settings button and "add senior" button
            HStack {
                SettingsExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)

                Button(action: {
                    showingMissedDashboard = true
                }) {
                    Image(systemName: hasNewMissedReminders ? "bell.badge.fill" : "bell")
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.7))
                }
                .navigationDestination(isPresented: $showingMissedDashboard) {
                    MissedRemindersView(firestoreManager: firestoreManager)
                }
                .onChange(of: showingMissedDashboard) { _, newValue in
                    if newValue {
                        hasNewMissedReminders = false
                    }
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
                            loadLinkedSeniors()
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
                    ForEach(seniors) { senior in
                        Button(action: {
                            firestoreManager.currentUID = senior.uid
                            DispatchQueue.main.async {
                                firestoreManager.isCaretakerViewingSenior = true
                                selectedSeniorUID = senior.uid
                                displayedName = senior.displayName
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(senior.displayName)
                                        .font(.headline)

                                    if senior.isFakeSenior {
                                        Text("Caretaker-created profile")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("@\(senior.username)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Menu {
                                    Button(role: .destructive) {
                                        let seniorToUnlink = senior

                                        // Optimistically remove the senior from the UI immediately.
                                        seniors.removeAll { $0.uid == seniorToUnlink.uid }

                                        firestoreManager.unlinkSenior(username: seniorToUnlink.username) { error in
                                            DispatchQueue.main.async {
                                                if let error = error {
                                                    print("Error unlinking senior: \(error.localizedDescription)")
                                                }

                                                // Refresh either way so the screen matches Firebase after the operation finishes.
                                                loadLinkedSeniors()
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
            loadLinkedSeniors()
            firestoreManager.getLinkedSeniorUIDs { seniorUIDs in
                firestoreManager.getRemindersForMultipleUsers(uids: seniorUIDs) { results in
                    
                    let now = Date()
                    var hasMissed = false

                    // Build UID -> firstName map for better ID generation
                    var nameMap: [String: String] = [:]
                    let group = DispatchGroup()
                    for uid in seniorUIDs {
                        group.enter()
                        firestoreManager.getUserFirstName(forUID: uid) { name in
                            nameMap[uid] = name ?? "Unknown"
                            group.leave()
                        }
                    }
                    group.notify(queue: .main) {
                        for (uid, reminders) in results {
                            for (_, reminder) in reminders {
                                let id = "\(reminder.title)_\(reminder.date.timeIntervalSince1970)_\(nameMap[uid] ?? "Unknown")"
                                let isCleared = getClearedSet().contains(id)
                                let isMissed = reminder.date < now && !reminder.isComplete && !isCleared

                                if isMissed {
                                    hasMissed = true
                                    break
                                }
                            }
                            if hasMissed { break }
                        }
                        DispatchQueue.main.async {
                            self.hasNewMissedReminders = hasMissed
                        }
                    }
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
    private func loadLinkedSeniors() {
        firestoreManager.fetchLinkedSeniorSummaries { summaries in
            DispatchQueue.main.async {
                self.seniors = summaries.map {
                    LinkedSeniorSummary(
                        uid: $0.uid,
                        displayName: $0.displayName,
                        username: $0.username,
                        isFakeSenior: $0.isFakeSenior
                    )
                }
            }
        }
    }
}


struct AddSeniorView: View {
    @Environment(\.dismiss) var dismiss
    let firestoreManager: FirestoreManager
    var onSuccess: (() -> Void)?
    @State private var username: String = ""
    @State private var fakeSeniorName: String = ""
    @State private var statusMessage: String = ""
    @State private var isCreatingProfile: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Add Senior")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Link a Senior With an Account")
                        .font(.headline)

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

                    Text("Ask the senior to open Settings and find their username so you can link your accounts.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(14)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Create a Senior Profile")
                        .font(.headline)

                    Text("Use this if the senior does not have a phone or cannot create an account. You will manage their reminders, and only you will receive notifications.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Senior's Name", text: $fakeSeniorName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .textContentType(.name)

                    Button(action: {
                        createSeniorProfile()
                    }) {
                        if isCreatingProfile {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Profile")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isCreatingProfile)
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .cornerRadius(14)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
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
                    DispatchQueue.main.async {
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

    private func createSeniorProfile() {
        isCreatingProfile = true
        statusMessage = ""

        firestoreManager.createFakeSeniorProfile(name: fakeSeniorName) { result in
            DispatchQueue.main.async {
                isCreatingProfile = false

                switch result {
                case .success:
                    statusMessage = "Senior profile created!"
                    onSuccess?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }

                case .failure(let error):
                    statusMessage = "Error creating profile: \(error.localizedDescription)"
                }
            }
        }
    }
}





// MOVE BELOW STRUCT TO ANOTHER FILE
struct MissedRemindersView: View {
    let firestoreManager: FirestoreManager
    @State private var missedReminders: [MissedReminder] = []
    @State private var selectedSeniorFilter: String = "All"
    @State private var showMissedOnly: Bool = true
    @State private var availableSeniors: [String] = ["All"]
    @State private var selectedReminder: MissedReminder?
    @AppStorage("clearedMissedReminders") private var clearedRemindersData: String = ""

    private func getClearedSet() -> Set<String> {
        Set(clearedRemindersData.split(separator: "|").map { String($0) })
    }

    private func saveClearedSet(_ set: Set<String>) {
        clearedRemindersData = set.joined(separator: "|")
    }

    private func clearReminder(_ reminder: MissedReminder) {
        var set = getClearedSet()
        set.insert(reminder.id)
        saveClearedSet(set)
        missedReminders.removeAll { $0.id == reminder.id }
    }

    private func clearAllReminders() {
        var set = getClearedSet()
        for reminder in missedReminders {
            set.insert(reminder.id)
        }
        saveClearedSet(set)
        missedReminders.removeAll()
    }

    var body: some View {
        VStack {
            HStack {
                ZStack {
                    HStack {
                        Spacer()
                        Menu {
                            ForEach(availableSeniors, id: \.self) { senior in
                                Button(senior) {
                                    selectedSeniorFilter = senior
                                    loadMissedReminders()
                                }
                            }
                        } label: {
                            HStack {
                                Text("Senior: \(selectedSeniorFilter)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                        }
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Button(action: {
                            clearAllReminders()
                        }) {
                            Text("Clear All")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal)

            List {
                if missedReminders.isEmpty {
                    Text("No missed reminders.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(missedReminders) { reminder in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reminder.title)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("Senior: \(reminder.seniorName)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Created by: \(reminder.createdBy)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(reminder.dateString)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedReminder = reminder
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                clearReminder(reminder)
                            } label: {
                                Label("Clear", systemImage: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                }
            }
            .onAppear {
                loadMissedReminders()
            }
            .alert(item: $selectedReminder) { reminder in
                Alert(
                    title: Text(reminder.title),
                    message: Text(reminder.description.isEmpty ? "No description." : reminder.description),
                    dismissButton: .default(Text("OK"))
                )
            }

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Toggle(isOn: $showMissedOnly) {
                    Text("Show Missed Only")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .onChange(of: showMissedOnly) { _, _ in
                    loadMissedReminders()
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.5), lineWidth: 2)
            )
            .padding(.horizontal)
            .padding(.top, 8)
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
            var caretakerNameMap: [String: String] = [:]
            let caretakerGroup = DispatchGroup()

            for uid in seniorUIDs {
                nameGroup.enter()
                firestoreManager.getUserFirstName(forUID: uid) { name in
                    nameMap[uid] = name ?? "Unknown"
                    nameGroup.leave()
                }
            }

            for uid in seniorUIDs {
                firestoreManager.getLinkedCaretakersForSenior(seniorUID: uid) { caretakerUIDs in
                    for caretakerUID in caretakerUIDs {
                        caretakerGroup.enter()
                        firestoreManager.getUserFirstName(forUID: caretakerUID) { name in
                            caretakerNameMap[caretakerUID] = name ?? "Caretaker"
                            caretakerGroup.leave()
                        }
                    }
                }
            }

            nameGroup.notify(queue: .main) {
                caretakerGroup.notify(queue: .main) {
                    firestoreManager.getRemindersForMultipleUsers(uids: seniorUIDs) { results in

                        var newMissed: [MissedReminder] = []
                        let now = Date()

                        for (uid, reminders) in results {
                            for (_, reminder) in reminders {
                                let scheduledDate = reminder.date
                                //let delay = reminder.caretakerAlertDelay
                                let deadline = scheduledDate

                                let id = "\(reminder.title)_\(scheduledDate.timeIntervalSince1970)_\(nameMap[uid] ?? "Unknown")"

                                if reminder.repeatSettings.repeat_type == "None" {
                                    if !reminder.isComplete {
                                        let createdBy = reminder.creator

                                        let reminderItem = MissedReminder(
                                            id: id,
                                            title: reminder.title,
                                            description: reminder.description,
                                            seniorName: nameMap[uid] ?? "Unknown",
                                            date: scheduledDate,
                                            dateString: formatDate(scheduledDate),
                                            createdBy: createdBy,
                                            isMissed: deadline < now
                                        )
                                        newMissed.append(reminderItem)
                                    }
                                } else {
                                    let completed = reminder.completedInstances.contains {
                                        Calendar.current.isDate($0, inSameDayAs: scheduledDate)
                                    }
                                    if !completed {
                                        let createdBy = reminder.creator

                                        let reminderItem = MissedReminder(
                                            id: id,
                                            title: reminder.title,
                                            description: reminder.description,
                                            seniorName: nameMap[uid] ?? "Unknown",
                                            date: scheduledDate,
                                            dateString: formatDate(scheduledDate),
                                            createdBy: createdBy,
                                            isMissed: deadline < now
                                        )
                                        newMissed.append(reminderItem)
                                    }
                                }
                            }
                        }

                        var filtered = newMissed
                        let clearedSet = getClearedSet()
                        filtered = filtered.filter { !clearedSet.contains($0.id) }

                        if selectedSeniorFilter != "All" {
                            filtered = filtered.filter { $0.seniorName == selectedSeniorFilter }
                        }

                        if showMissedOnly {
                            filtered = filtered.filter { $0.isMissed }
                        }

                        self.availableSeniors = ["All"] + Array(Set(newMissed.map { $0.seniorName }))

                        self.missedReminders = filtered.sorted {
                            $0.date > $1.date
                        }
                    }
                }
            }
        }
    }
}

struct MissedReminder: Identifiable {
    let id: String   // stable ID
    let title: String
    let description: String
    let seniorName: String
    let date: Date
    let dateString: String
    let createdBy: String
    let isMissed: Bool
}
