//
//  Notifications.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/22/25.
//

import UserNotifications

func requestNotificationPermission() {
    let center = UNUserNotificationCenter.current()
    center.delegate = NotificationDelegate.shared
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("Permission granted")
        } else {
            print("Permission denied")
        }
    }
}

//Used to allow notifications to pop up even if app is running in the foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}


func setAlarm(dateAndTime: Date, title: String, description: String, repeat_type: String, repeat_until_date: String, repeatIntervals: CustomRepeatType?, reminderID: String, soundType: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = description
    content.sound = soundType == "Alert" 
        ? UNNotificationSound(named: UNNotificationSoundName("notification_alert.wav"))
        : UNNotificationSound(named: UNNotificationSoundName("chord_iphone.WAV"))
    
    let calendar = Calendar.current
    let baseIdentifier = createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID))
    
    if repeat_type == "Custom", let repeatIntervals = repeatIntervals, let daysString = repeatIntervals.days {
        // Handle custom repeat patterns
        let patterns = daysString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        for (index, pattern) in patterns.enumerated() {
            if let nextDate = calculateNextDateForPattern(pattern: pattern, from: dateAndTime) {
                let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "\(baseIdentifier)-\(index)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error adding custom notification: \(error)")
                    } else {
                        print("Scheduled custom notification for \(nextDate)")
                    }
                }
            }
        }
    } else {
        // Handle regular notifications
        if repeat_type == "Daily" {
            let dateComponents = calendar.dateComponents([.hour, .minute], from: dateAndTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding daily notification: \(error)")
                } else {
                    print("Successfully added daily notification")
                }
            }
        } else if repeat_type == "Weekly" {
            let dateComponents = calendar.dateComponents([.weekday, .hour, .minute], from: dateAndTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding weekly notification: \(error)")
                } else {
                    print("Successfully added weekly notification")
                }
            }
        } else if repeat_type == "Monthly" {
            let dateComponents = calendar.dateComponents([.weekly, .hour, .minute], from: dateAndTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding monthly notification: \(error)")
                } else {
                    print("Successfully added monthly notification")
                }
            }
        } else if repeat_type == "Yearly" {
            let dateComponents = calendar.dateComponents([.month, .day, .hour, .minute], from: dateAndTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding yearly notification: \(error)")
                } else {
                    print("Successfully added yearly notification")
                }
            }
        } else {
            // Non-repeating or monthly (monthly needs special handling)
            let shouldRepeat = false
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dateAndTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: shouldRepeat)
            let request = UNNotificationRequest(identifier: baseIdentifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding notification: \(error)")
                } else {
                    print("Successfully added notification for \(dateAndTime)")
                }
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

//func setAlarm(dateAndTime: Date, title: String, description: String, repeat_type: String, repeat_until_date: String, repeatIntervals: CustomRepeatType?, reminderID: String, soundType: String) {
//    let content = UNMutableNotificationContent()
//    content.title = title
//    content.body = description
//    content.sound = soundType == "Alert"
//        ? UNNotificationSound(named: UNNotificationSoundName("notification_alert.wav"))
//        : UNNotificationSound(named: UNNotificationSoundName("chord_iphone.WAV"))
//
//    var triggers: [Date] = []
//    
//    let calendar = Calendar.current
//    let startDate = dateAndTime
//    
//    // Parse repeat_until_date
//    var endDate: Date? = nil
//    if repeat_until_date != "Forever" && !repeat_until_date.isEmpty {
//        let fmt = DateFormatter()
//        fmt.dateStyle = .medium
//        endDate = fmt.date(from: repeat_until_date)
//    }
//
//    // Helper to add dates for repeats
//    func addRepeatingDates(interval: DateComponents) {
//        var nextDate = startDate
//        while endDate == nil || nextDate <= endDate! {
//            triggers.append(nextDate)
//            if let d = calendar.date(byAdding: interval, to: nextDate) {
//                nextDate = d
//            } else {
//                break
//            }
//        }
//    }
//
//    switch repeat_type {
//    case "None":
//        triggers.append(startDate)
//        
//    case "Daily":
//        addRepeatingDates(interval: DateComponents(day: 1))
//        
//    case "Weekly":
//        addRepeatingDates(interval: DateComponents(weekOfYear: 1))
//        
//    case "Custom":
//        if let repeatIntervals = repeatIntervals, let daysString = repeatIntervals.days {
//            let weekdays = daysString.split(separator: ",").compactMap { weekdayFromString(String($0)) }
//            for weekday in weekdays {
//                var nextDate = startDate
//                while endDate == nil || nextDate <= endDate! {
//                    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextDate)
//                    if let dayDate = calendar.nextDate(after: nextDate, matching: DateComponents(hour: calendar.component(.hour, from: startDate), minute: calendar.component(.minute, from: startDate), weekday: weekday), matchingPolicy: .nextTime) {
//                        if endDate == nil || dayDate <= endDate! {
//                            triggers.append(dayDate)
//                            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: dayDate) ?? dayDate.addingTimeInterval(604800)
//                        } else {
//                            break
//                        }
//                    } else {
//                        break
//                    }
//                }
//            }
//        }
//        
//    default:
//        triggers.append(startDate)
//    }
//
//    // Schedule notifications
//    for (index, triggerDate) in triggers.enumerated() {
//        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
//        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
//        let identifier = "\(createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID)))-\(index)"
//        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error adding notification: \(error)")
//            } else {
//                print("Scheduled notification \(identifier) for \(triggerDate)")
//            }
//        }
//    }
//}

func cancelAlarm(reminderID: String) {
    let identifier = createUniqueIDFromDate(date: createExactDateFromString(dateString: reminderID))
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    print("Cancelled notification with ID: \(identifier)")
}
