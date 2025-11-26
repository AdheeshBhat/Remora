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
    private let maxScheduledNotifications = 50 // iOS limit is 64
    
    private init() {}
    
    func scheduleForeverRepeatingAlarm(reminder: ReminderData, reminderID: String) {
        guard reminder.repeatSettings.repeat_until_date == "Forever" else {
            FirestoreManager().loadUserSettings(field: "selectedSound") { soundValue in
                let soundType = (soundValue as? String) ?? "Chord"
                // Use existing setAlarm function for non-forever alarms
                setAlarm(
                    dateAndTime: reminder.date,
                    title: reminder.title,
                    description: reminder.description,
                    repeat_type: reminder.repeatSettings.repeat_type,
                    repeat_until_date: reminder.repeatSettings.repeat_until_date,
                    repeatIntervals: reminder.repeatSettings.repeatIntervals,
                    reminderID: reminderID,
                    soundType: soundType
                )
            }
            return
        }
        
        // Schedule initial batch for forever repeating alarms
        scheduleNextBatch(reminder: reminder, reminderID: reminderID, startDate: reminder.date)
    }
    
    private func scheduleNextBatch(reminder: ReminderData, reminderID: String, startDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.description
        FirestoreManager().loadUserSettings(field: "selectedSound") { soundValue in
            let soundType = (soundValue as? String) ?? "Chord"
            let soundFileName: String

            switch soundType.lowercased() {
            case "alert":
                soundFileName = "notification_alert.wav"
            case "xylophone":
                soundFileName = "xylophone.wav"
            case "marimba 1":
                soundFileName = "marimba1.wav"
            case "marimba 2":
                soundFileName = "marimba2.wav"
            default:
                soundFileName = "chord_iphone.WAV"
            }

            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFileName))
        }
        
        var scheduledDates: [Date] = []
        let calendar = Calendar.current
        var currentDate = startDate
        
        // Parse repeat_until_date
        var endDate: Date? = nil
        if reminder.repeatSettings.repeat_until_date != "Forever" && !reminder.repeatSettings.repeat_until_date.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            endDate = fmt.date(from: reminder.repeatSettings.repeat_until_date)
        }
        
        // Generate next batch of dates
        for _ in 0..<maxScheduledNotifications {
            // Check if we've reached the repeat_until_date
            if let endDate = endDate, currentDate > endDate {
                break
            }
            scheduledDates.append(currentDate)
            currentDate = getNextOccurrence(from: currentDate, repeatType: reminder.repeatSettings.repeat_type, repeatIntervals: reminder.repeatSettings.repeatIntervals)
        }
        
        // Schedule notifications
        for (index, date) in scheduledDates.enumerated() {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = "\(createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID)))-\(index)"
            
            // Add custom data to reschedule next batch
            if index == maxScheduledNotifications - 1 {
                content.userInfo = [
                    "isLastInBatch": true,
                    "reminderID": reminderID,
                    "nextStartDate": currentDate.timeIntervalSince1970
                ]
            }
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
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
                    
                    self.scheduleNextBatch(reminder: reminder, reminderID: reminderID, startDate: nextStartDate)
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
        let isComplete = data["isComplete"] as? Bool ?? false
        let isLocked = data["isLocked"] as? Bool ?? false
        
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
            isLocked: isLocked
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
                
                self.scheduleNextBatch(reminder: reminder, reminderID: reminderID, startDate: nextDate)
            }
        }
    }
    
    private func cancelForeverAlarm(reminderID: String) {
        let baseIdentifier = createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID))
        
        var identifiersToCancel: [String] = []
        for i in 0..<maxScheduledNotifications {
            identifiersToCancel.append("\(baseIdentifier)-\(i)")
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
    }
}
