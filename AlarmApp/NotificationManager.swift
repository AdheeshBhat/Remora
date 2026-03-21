//
//  NotificationManager.swift
//  AlarmApp
//
//  Created by AI Assistant
//

import UserNotifications
import Foundation
import FirebaseFirestore

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private let maxScheduledNotifications = 30 // iOS limit is 64
    
    private init() {}
    
    // Main function to schedule "forever repeating" reminders
    // This handles reminders that are set to repeat infinitely ("Forever")
    // It schedules the first batch of notifications, then uses batching to avoid iOS limits
    func scheduleForeverRepeatingAlarm(
        reminder: ReminderData,
        reminderID: String,
        isCaretakerNotification: Bool = false,
        seniorName: String? = nil
    ) {
        
        // Schedule initial batch for forever repeating alarms
        scheduleNextBatch(
            reminder: reminder,
            reminderID: reminderID,
            startDate: reminder.date,
            isCaretakerNotification: isCaretakerNotification,
            seniorName: seniorName
        )
    }
    
    private func stripSeconds(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: comps)!
    }
    
    //Private function to schedule a batch of notifications for a "forever" repeating reminder
    // iOS limits the number of local notifications you can schedule at once (max ~64),
    // so we schedule them in batches and schedule the next batch dynamically
    private func scheduleNextBatch(
        reminder: ReminderData,
        reminderID: String,
        startDate: Date,
        isCaretakerNotification: Bool,
        seniorName: String? = nil
    ) {
        // Create a new UNNotificationContent object to hold the notification data
        let content = UNMutableNotificationContent()
        
        //Different content depending on whether it's a caretaker notification
        if isCaretakerNotification {
            let senior = seniorName ?? "Senior"
            content.title = "🚨 \(senior)'s Reminder"
            content.body = "\"\(reminder.title)\" is not finished yet."
            content.userInfo = [
                "role": "caretaker",
                "reminderID": reminderID,
                "seniorName": senior,
                "reminderTitle": reminder.title
            ]
        } else {
            //Regular notification for the senior
            content.title = reminder.title
            content.body = reminder.description
            content.userInfo = [
                "role": "senior",
                "reminderID": reminderID
            ]
        }

        // Load the user's selected notification sound from Firestore
        FirestoreManager().loadUserSettings(field: "selectedSound") { soundValue in
            let soundType = (soundValue as? String) ?? "Chord"
            let soundFileName: String
            
            // Map the selected sound type to the corresponding audio file
            switch soundType.lowercased() {
            case "alert":
                soundFileName = "notification_alert.wav"
            case "xylophone":
                soundFileName = "xylophone.wav"
            case "marimba 1":
                soundFileName = "marimba1.wav"
            case "marimba 2":
                soundFileName = "marimba2.wav"
            case "chime":
                soundFileName = "chime.wav"
            case "pulse":
                soundFileName = "pulse.wav"
            default:
                soundFileName = "chord_iphone.WAV"
            }

            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFileName))
            var scheduledDates: [Date] = []                   // Will hold the list of dates for this batch
            let calendar = Calendar.current
            var currentDate = self.stripSeconds(startDate)
            
            // Parse optional endDate (if repeat_until_date is NOT "Forever")
            var endDate: Date? = nil
            if reminder.repeatSettings.repeat_until_date != "Forever" && !reminder.repeatSettings.repeat_until_date.isEmpty {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                endDate = fmt.date(from: reminder.repeatSettings.repeat_until_date)
            }
            
            // Generate next batch of dates
            for _ in 0..<self.maxScheduledNotifications {
                // Check if we've reached the repeat_until_date
                if let endDate = endDate, currentDate > endDate {
                    break
                }
                scheduledDates.append(currentDate)
                currentDate = self.getNextOccurrence(from: currentDate, repeatType: reminder.repeatSettings.repeat_type, repeatIntervals: reminder.repeatSettings.repeatIntervals)
            }
            //print("Triggers to schedule for 'forever' reminder \(reminderID): \(scheduledDates)")
            
            // Schedule each notification in the batch
            for (index, date) in scheduledDates.enumerated() {
                // Apply caretaker alert delay if this is a caretaker notification
                let mainDate = isCaretakerNotification
                    ? date.addingTimeInterval(reminder.caretakerAlertDelay)
                    : date

                // Create date components for UNCalendarNotificationTrigger
                let comps = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: mainDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let role = isCaretakerNotification ? "caretaker" : "senior"
                // Unique identifier for this notification (used for cancelling/rescheduling later)
                let identifier =
                    "\(createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID)))-\(index)-\(role)"
                
                // Add custom data to reschedule next batch
                if index == self.maxScheduledNotifications - 1 {
                    var lastBatchUserInfo: [String: Any] = [
                        "isLastInBatch": true,
                        "reminderID": reminderID,
                        "nextStartDate": currentDate.timeIntervalSince1970,
                        "role": role
                    ]
                    if let seniorName = seniorName, isCaretakerNotification {
                        lastBatchUserInfo["seniorName"] = seniorName            // Include senior's name for caretaker notifications
                    }
                    content.userInfo = lastBatchUserInfo
                }
                
                // Create the notification request and schedule it with UNUserNotificationCenter
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error scheduling main notification: \(error)")
                    } else {
                        //print("Scheduled main notification for forever alarm: \(identifier) at \(mainDate)")
                    }
                }
                
                // Only schedule follow-up notifications for seniors
                if !isCaretakerNotification {
                    // Schedule follow-up notification for forever alarms
                    let halfDelaySeconds = reminder.caretakerAlertDelay / 2
                    let followUpDate = date.addingTimeInterval(halfDelaySeconds)

                    // Build follow-up content
                    let followUpContent = UNMutableNotificationContent()
                    followUpContent.title = "Reminder: \(reminder.title)"
                    followUpContent.body = "Make sure to mark ‘\(reminder.title)’ as done! Caretaker alert in \(Int((reminder.caretakerAlertDelay/2)/60)) min."
                    followUpContent.sound = content.sound
                    followUpContent.userInfo = [
                        "isFollowUp": true,
                        "reminderID": reminderID,
                        "role": "senior"
                    ]

                    // Schedule follow-up only if the time is in the future
                    let timeInterval = followUpDate.timeIntervalSinceNow
                    if timeInterval > 0 {
                        let followUpTrigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)

                        // Unique identifier (parallel to normal follow-up IDs)
                        let followUpIdentifier = "\(createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID)))-followup-\(index)-senior"

                        let followUpRequest = UNNotificationRequest(identifier: followUpIdentifier, content: followUpContent, trigger: followUpTrigger)

                        UNUserNotificationCenter.current().add(followUpRequest)
                    } else {
                        print("Skipped follow-up notification for \(reminderID) because interval is \(timeInterval) seconds")
                    }
                }
            }
        }
    }
    
    private func getNextOccurrence(from date: Date, repeatType: String, repeatIntervals: CustomRepeatType?) -> Date {
        let calendar = Calendar.current
        
        switch repeatType {
        case "Daily":
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case "Weekly":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case "Monthly":
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case "Yearly":
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case "Custom":
            // Handle custom repeat patterns
            if let intervals = repeatIntervals, let daysString = intervals.days {
                return calculateNextDateForPattern(pattern: daysString, from: date) ?? calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        default:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
    }
    
    func handleNotificationResponse(response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        if let isLastInBatch = userInfo["isLastInBatch"] as? Bool, isLastInBatch,
           let reminderID = userInfo["reminderID"] as? String,
           let nextStartTimestamp = userInfo["nextStartDate"] as? TimeInterval {
            
            let nextStartDate = Date(timeIntervalSince1970: nextStartTimestamp)
            // Determine role for the next batch
            let role = userInfo["role"] as? String ?? "senior"
            let isCaretakerNotification = (role == "caretaker")
            let seniorName = userInfo["seniorName"] as? String
            // Fetch reminder data and schedule next batch
            FirestoreManager().getReminder(dateCreated: reminderID) { document in
                if let document = document,
                   let data = document.data(),
                   let reminder = self.parseReminderFromDocument(data: data) {
                    
                    // Check if we've exceeded repeat_until_date
                    if reminder.repeatSettings.repeat_until_date != "Forever" && !reminder.repeatSettings.repeat_until_date.isEmpty {
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyy-MM-dd"
                        if let endDate = fmt.date(from: reminder.repeatSettings.repeat_until_date),
                           nextStartDate > endDate {
                            return // Don't schedule more notifications
                        }
                    }
                    
                    self.scheduleNextBatch(
                        reminder: reminder,
                        reminderID: reminderID,
                        startDate: nextStartDate,
                        isCaretakerNotification: isCaretakerNotification,
                        seniorName: seniorName
                    )
                }
            }
        }
    }
    
    private func parseReminderFromDocument(data: [String: Any]) -> ReminderData? {
        let id = data["ID"] as? Int ?? 0
        let title = data["title"] as? String ?? ""
        let description = data["description"] as? String ?? ""
        let priority = data["priority"] as? String ?? "Low"
        let author = data["author"] as? String ?? "user"
        let creator = data["creator"] as? String ?? author
        let isComplete = data["isComplete"] as? Bool ?? false
        let isLocked = data["isLocked"] as? Bool ?? false
        let caretakerAlertDelay = data["caretakerAlertDelay"] as? TimeInterval ?? 1800
        
        guard let timestamp = data["date"] as? Timestamp else { return nil }
        let date = timestamp.dateValue()
        
        let repeatSettings: RepeatSettings
        if let rsMap = data["repeatSettings"] as? [String: Any] {
            let repeatType = rsMap["repeat_type"] as? String ?? "None"
            let repeatUntil = rsMap["repeat_until_date"] as? String ?? ""
            
            let repeatIntervals: CustomRepeatType?
            if let intervalsMap = rsMap["repeatIntervals"] as? [String: Any] {
                let days = intervalsMap["days"] as? String
                let weeks = intervalsMap["weeks"] as? [Int]
                let months = intervalsMap["months"] as? [Int]
                repeatIntervals = CustomRepeatType(days: days, weeks: weeks, months: months)
            } else {
                repeatIntervals = nil
            }
            
            repeatSettings = RepeatSettings(repeat_type: repeatType, repeat_until_date: repeatUntil, repeatIntervals: repeatIntervals)
        } else {
            repeatSettings = RepeatSettings(repeat_type: "None", repeat_until_date: "")
        }
        
        return ReminderData(
            ID: id,
            date: date,
            title: title,
            description: description,
            repeatSettings: repeatSettings,
            priority: priority,
            isComplete: isComplete,
            author: author,
            creator: creator,
            isLocked: isLocked,
            caretakerAlertDelay: caretakerAlertDelay
        )
    }
    
    func refreshForeverAlarms() {
        // Call this when app becomes active to refresh expired alarms
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let now = Date()
            let expiredCount = requests.filter { request in
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    return nextTriggerDate < now
                }
                return false
            }.count
            
            // If we have fewer than 10 pending notifications, refresh all forever alarms
            if requests.count - expiredCount < 10 {
                self.refreshAllForeverAlarms()
            }
        }
    }
    
    private func refreshAllForeverAlarms() {
        FirestoreManager().getForeverReminders { [weak self] reminders in
            guard let self = self, let reminders = reminders else { return }
            
            for (reminderID, reminder) in reminders {
                // Cancel existing notifications for this reminder
                self.cancelForeverAlarm(reminderID: reminderID)
                
                // Check if reminder hasn't expired
                if reminder.repeatSettings.repeat_until_date != "Forever" && !reminder.repeatSettings.repeat_until_date.isEmpty {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy-MM-dd"
                    if let endDate = fmt.date(from: reminder.repeatSettings.repeat_until_date),
                       Date() > endDate {
                        return // Don't reschedule expired reminders
                    }
                }
                
                // Reschedule from next occurrence
                let nextDate = self.getNextOccurrence(
                    from: Date(),
                    repeatType: reminder.repeatSettings.repeat_type,
                    repeatIntervals: reminder.repeatSettings.repeatIntervals
                )
                
                self.scheduleNextBatch(
                    reminder: reminder,
                    reminderID: reminderID,
                    startDate: nextDate,
                    isCaretakerNotification: false
                )
            }
        }
    }
    
    func cancelForeverAlarm(reminderID: String) {
        let baseIdentifier = createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID))
        
        var identifiersToCancel: [String] = []
        for i in 0..<maxScheduledNotifications {
            identifiersToCancel.append("\(baseIdentifier)-\(i)-senior")
            identifiersToCancel.append("\(baseIdentifier)-\(i)-caretaker")
            identifiersToCancel.append("\(baseIdentifier)-followup-\(i)")
            identifiersToCancel.append("\(baseIdentifier)-followup-\(i)-senior")
        }
        
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        print("Cancelled ALL 'forever' notifications (senior: main + follow-up, caretaker) with base ID: \(baseIdentifier)")

    }
}
