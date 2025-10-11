//
//  Notifications.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/22/25.
//

import UserNotifications

func requestNotificationPermission() {
    let center = UNUserNotificationCenter.current()
    center.delegate = AppNotificationDelegate.shared
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("Permission granted")
        } else {
            print("Permission denied")
        }
    }
}


func setAlarm(dateAndTime: Date, title: String, description: String, repeat_type: String, repeat_until_date: String, repeatIntervals: CustomRepeatType?, reminderID: String, soundType: String) {
    // Handle forever repeating alarms with NotificationManager
    if repeat_until_date == "Forever" {
        let reminder = ReminderData(
            ID: 0,
            date: dateAndTime,
            title: title,
            description: description,
            repeatSettings: RepeatSettings(
                repeat_type: repeat_type,
                repeat_until_date: repeat_until_date,
                repeatIntervals: repeatIntervals
            ),
            priority: "Low",
            isComplete: false,
            author: "user",
            isLocked: false
        )
        NotificationManager.shared.scheduleForeverRepeatingAlarm(reminder: reminder, reminderID: reminderID)
        return
    }
    
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = description
    content.sound = soundType == "Alert"
        ? UNNotificationSound(named: UNNotificationSoundName("notification_alert.wav"))
        : UNNotificationSound(named: UNNotificationSoundName("chord_iphone.WAV"))

    var triggers: [Date] = []
    
    let calendar = Calendar.current
    let startDate = dateAndTime
    
    // Parse repeat_until_date
    var endDate: Date? = nil
    if repeat_until_date != "Forever" && !repeat_until_date.isEmpty {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        endDate = fmt.date(from: repeat_until_date)
    }

    // Helper to add dates for repeats
    func addRepeatingDates(interval: DateComponents) {
        var nextDate = startDate
        let maxOccurrences = 100 // Prevent infinite loops
        var count = 0
        while (endDate == nil || nextDate <= endDate!) && count < maxOccurrences {
            triggers.append(nextDate)
            if let d = calendar.date(byAdding: interval, to: nextDate) {
                nextDate = d
            } else {
                break
            }
            count += 1
        }
    }

    switch repeat_type {
    case "None":
        triggers.append(startDate)
        
    case "Daily":
        addRepeatingDates(interval: DateComponents(day: 1))
        
    case "Weekly":
        addRepeatingDates(interval: DateComponents(weekOfYear: 1))
        
    case "Monthly":
        addRepeatingDates(interval: DateComponents(month: 1))
        
    case "Yearly":
        addRepeatingDates(interval: DateComponents(year: 1))
        
    case "Custom":
        if let repeatIntervals = repeatIntervals, let daysString = repeatIntervals.days {
            let patterns = daysString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            for pattern in patterns {
                var currentDate = startDate
                let maxOccurrences = 100
                var count = 0
                while (endDate == nil || currentDate <= endDate!) && count < maxOccurrences {
                    if let nextDate = calculateNextDateForPattern(pattern: pattern, from: currentDate) {
                        if endDate == nil || nextDate <= endDate! {
                            triggers.append(nextDate)
                            currentDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                    count += 1
                }
            }
        }
        
    default:
        triggers.append(startDate)
    }

    // Schedule notifications
    for (index, triggerDate) in triggers.enumerated() {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let identifier = "\(createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID)))-\(index)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error adding notification: \(error)")
            } else {
                print("Scheduled notification \(identifier) for \(triggerDate)")
            }
        }
    }
}

func calculateNextDateForPattern(pattern: String, from baseDate: Date) -> Date? {
    let calendar = Calendar.current
    let components = pattern.split(separator: " ")
    guard components.count == 2 else { return nil }
    
    let ordinal = String(components[0])
    let dayName = String(components[1])
    
    // Convert day name to weekday number
    let weekdayMap = ["Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7, "Sun": 1]
    guard let weekday = weekdayMap[dayName] else { return nil }
    
    // Extract ordinal number
    let ordinalNumber: Int
    if ordinal.hasPrefix("1st") { ordinalNumber = 1 }
    else if ordinal.hasPrefix("2nd") { ordinalNumber = 2 }
    else if ordinal.hasPrefix("3rd") { ordinalNumber = 3 }
    else if ordinal.hasPrefix("4th") { ordinalNumber = 4 }
    else { return nil }
    
    // Find the next occurrence
    let baseComponents = calendar.dateComponents([.hour, .minute], from: baseDate)
    let currentDate = Date()
    
    for monthOffset in 0..<12 {
        if let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: currentDate) {
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: targetMonth))!
            
            // Find the nth occurrence of the weekday in this month
            var occurrenceCount = 0
            for day in 1...31 {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
                   calendar.component(.month, from: date) == calendar.component(.month, from: targetMonth),
                   calendar.component(.weekday, from: date) == weekday {
                    occurrenceCount += 1
                    if occurrenceCount == ordinalNumber {
                        let finalDate = calendar.date(bySettingHour: baseComponents.hour ?? 0, minute: baseComponents.minute ?? 0, second: 0, of: date)!
                        if finalDate > currentDate {
                            return finalDate
                        }
                    }
                }
            }
        }
    }
    return nil
}



func cancelAlarm(reminderID: String) {
    let baseIdentifier = createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID))
    
    // Cancel the base notification and all indexed variations
    var identifiersToCancel = [baseIdentifier]
    for i in 0..<100 {
        identifiersToCancel.append("\(baseIdentifier)-\(i)")
    }
    
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
    print("Cancelled notifications with base ID: \(baseIdentifier)")
}
