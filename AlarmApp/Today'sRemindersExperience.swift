import SwiftUI


struct TodayRemindersExperience: View {
    @Binding var cur_screen: Screen
    var isHideCompletedReminders: Bool
    var firestoreManager: FirestoreManager

    @State private var reminders: [String: ReminderData] = [:]
    @State private var isLoading = true

    private func reloadReminders() {
        self.isLoading = true
        firestoreManager.getRemindersForUser { fetchedReminders in
            DispatchQueue.main.async {
                self.reminders = fetchedReminders ?? [:]
                self.isLoading = false
            }
        }
    }

    var body: some View {
        VStack {
            Text("Today's Reminders")
                .font(.title)
                .underline()

//            if isLoading {
//                Spacer()
//                ProgressView("Loading...")
//                Spacer()
//            } else {
                Group {
                    let expandedTodayReminders = expandRepeatingReminders(
                        userData: reminders,
                        period: "today",
                        filteredDay: Date()
                    )

                    let visibleReminders = isHideCompletedReminders
                        ? expandedTodayReminders.filter { !$0.value.isComplete }
                        : expandedTodayReminders
                    
                    if visibleReminders.isEmpty {
                        Spacer()
                        Text("No pending reminders 🙂")
                            .font(.title)
                            .foregroundColor(.primary)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack {
                                ForEach(visibleReminders.sorted(by: { $0.value.date < $1.value.date }), id: \.key) { (documentID, reminder) in
                                    ReminderRow(
                                        cur_screen: $cur_screen,
                                        title: getTitle(reminder: reminder),
                                        time: getTimeFromReminder(reminder: reminder),
                                        reminderDate: getMonthFromReminder(reminder: reminder),
                                        reminder: reminder,
                                        showEditButton: false,
                                        showDeleteButton: false,
                                        userID: 1,
                                        dateKey: reminder.date,
                                        documentID: documentID.components(separatedBy: "-")[0],
                                        firestoreManager: firestoreManager,
                                        onUpdate: {
                                            reloadReminders()
                                        }
                                    )
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.primary, lineWidth: 2))
                        .padding(.horizontal)
                    }
                }
            //}

            Spacer()
        }
        .onAppear {
            reloadReminders()
        }
        .onChange(of: isHideCompletedReminders) { _, _ in
            reloadReminders()
        }
    }
}
