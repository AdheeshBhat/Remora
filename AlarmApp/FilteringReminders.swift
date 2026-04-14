//
//  FilteringReminders.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 6/17/25.
//

import SwiftUI

// ↓ REMINDER FILTERS ↓

func filterRemindersForToday(userData: [Date: ReminderData], filteredDay: Date?, hideCompleted: Bool) -> [Date: ReminderData] {
    let calendar = Calendar.current
    let today = Date()
    var startOfDay = calendar.startOfDay(for: today)
    if let filteredDay = filteredDay {
        startOfDay = calendar.startOfDay(for: filteredDay)
    }
    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)!
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        // deletedInstances stores dates of removed occurences. If today's instance appears in that list, we skip it
        let isCompleted = reminder.completedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate)}
        let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate) }
        print("deletedInstances in reminder struct: \(reminder.deletedInstances)")
        return reminderDate >= startOfDay && reminderDate <= endOfDay && !isDeleted && (!hideCompleted || !isCompleted)
    }
}

func filterRemindersForWeek(userData: [Date: ReminderData], filteredDay: Date?, hideCompleted: Bool) -> [Date: ReminderData] {
    let calendar = Calendar.current
    let today = Date()
    //(start of the week always begins on Sunday in this case) RAISES SAME QUESTION AS FOR MONTH FILTER
    var startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
    if let filteredDay = filteredDay {
        startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: filteredDay))!
    }
    var endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
    endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek)!
    
    print("Week filter - Start: \(startOfWeek), End: \(endOfWeek)")
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        // deletedInstances stores dates of removed occurences. If this week's instance appears in that list, we skip it
        let isCompleted = reminder.completedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate)}
        let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate) }
        return reminderDate >= startOfWeek && reminderDate <= endOfWeek && !isDeleted && (!hideCompleted || !isCompleted)
    }
}


//DOES CURRENT MONTH MEAN ex. MAR 1 - MAR 31 or ex. MAR 30 - APR 30?
    //Today's date is at the top of the page, and scroll up/down from MAR 1 - MAR 31, swipe left/right for next/previous month
func filterRemindersForMonth(userData: [Date: ReminderData], filteredDay: Date?, hideCompleted: Bool) -> [Date: ReminderData] {
    let calendar = Calendar.current
    let today = Date()
    var startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
    if let filteredDay = filteredDay {
        startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: filteredDay))!
    }

    let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
    let inclusiveEndOfMonth = calendar.date(byAdding: .second, value: -1, to: endOfMonth)!
    
    print("Month filter - Start: \(startOfMonth), End: \(inclusiveEndOfMonth)")
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        // deletedInstances stores dates of removed occurences. If this month's instance appears in that list, we skip it
        let isCompleted = reminder.completedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate)}
        let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate) }
        return reminderDate >= startOfMonth && reminderDate <= inclusiveEndOfMonth && !isDeleted && (!hideCompleted || !isCompleted)
    }
}

//----------------------------------------------------------------- 3

func dayHeader(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
}

func weekHeader(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    let calendar = Calendar.current
    let startOfWeek = calendar.date(
        from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    )!
    return formatter.string(from: startOfWeek)
}

// Main renderer for the reminders screen after repeating reminders have already been expanded
func formattedReminders(userID: Int, period: String, cur_screen: Binding<Screen>, showEditButton: Bool = true, showDeleteButton: Bool = false, filteredDay: Date?, firestoreManager: FirestoreManager, userData: [String: ReminderData], onUpdate: (() -> Void)? = nil) -> some View {
    //let expandedReminders = expandRepeatingReminders(userData: userData, period: period, filteredDay: filteredDay)
    let sortedReminders = userData.sorted { $0.value.date < $1.value.date }

    let calendar = Calendar.current

    return VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(sortedReminders.enumerated()), id: \.element.key) { index, element in
            let documentID = element.key
            let reminder = element.value
            let date = reminder.date

            let previousReminder: ReminderData? =
                index > 0 ? sortedReminders[index - 1].value : nil

            let isNewDay =
                previousReminder == nil ||
                !calendar.isDate(
                    date,
                    inSameDayAs: previousReminder!.date
                )

            let isNewWeek =
                previousReminder == nil ||
                calendar.component(.weekOfYear, from: date) !=
                calendar.component(.weekOfYear, from: previousReminder!.date)

            VStack(alignment: .leading, spacing: 12) {

                // WEEK → group by day
                if period == "week" && isNewDay {
                    Text(dayHeader(from: date))
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Divider().opacity(0.4)
                }

                // MONTH → group by week
                if period == "month" && isNewWeek {
                    Text("Week of \(weekHeader(from: date))")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Divider().opacity(0.4)
                }

                ReminderRow(
                    cur_screen: cur_screen,
                    title: getTitle(reminder: reminder),
                    time: getTimeFromReminder(reminder: reminder),
                    reminderDate: getMonthFromReminder(reminder: reminder),
                    reminder: reminder,
                    showEditButton: showEditButton,
                    showDeleteButton: showDeleteButton,
                    userID: userID,
                    dateKey: reminder.date,
                    documentID: documentID.components(separatedBy: "-")[0],
                    firestoreManager: firestoreManager,
                    onUpdate: onUpdate
                )
            }
        }
    }
}

// Generates virtual reminder instances that only exist in memory
func expandRepeatingReminders(userData: [String: ReminderData], period: String, filteredDay: Date?, hideCompleted: Bool) -> [String: ReminderData] {
    // Holds the final expanded reminders that the UI renders
    var expandedData: [String: ReminderData] = [:]
    let calendar = Calendar.current
    
    // Determine date range based on period (today/week/month)
    let (startDate, endDate) = {
        let today = filteredDay ?? Date()
        switch period {
        case "today":
            let start = calendar.startOfDay(for: today)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start)!
            return (start, end)
        case "week":
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            let end = calendar.date(byAdding: .day, value: 6, to: start)!
            return (start, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
        case "month":
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let exclusiveEnd = calendar.date(byAdding: .month, value: 1, to: start)!
            let end = calendar.date(byAdding: .second, value: -1, to: exclusiveEnd)!
            return (start, end)
        default:
            return (today, calendar.date(byAdding: .year, value: 1, to: today)!)
        }
    }()
    
    // Loop through every reminder document from Firestore
    for (documentID, reminder) in userData {
        // How this reminder repeats (None, Daily, Weekly, Custom, etc.)
        let repeatType = reminder.repeatSettings.repeat_type
        
        // Only include this reminder if:
        // 1. Its date is inside the selected range
        // 2. This specific instance was NOT deleted
        if repeatType == "None" {
            // Non-repeating reminder
            if reminder.date >= startDate && reminder.date <= endDate &&
                (!hideCompleted || !reminder.completedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date)} )) &&
               !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }) {
                expandedData[documentID] = reminder
                
            }
        } else if repeatType == "Custom" {
            if let intervals = reminder.repeatSettings.repeatIntervals, let daysString = intervals.days {
                let calendar = Calendar.current
                let dayNumbers = daysString
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                
                var seenDates = Set<String>()
                var currentMonthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: reminder.date))!
                
                while currentMonthDate <= endDate && seenDates.count < 50 {
                    let year = calendar.component(.year, from: currentMonthDate)
                    let month = calendar.component(.month, from: currentMonthDate)
                    
                    for day in dayNumbers {
                        var components = DateComponents()
                        components.year = year
                        components.month = month
                        components.day = day
                        
                        if let occurrenceDate = calendar.date(from: components) {
                            let finalDate = calendar.date(
                                bySettingHour: calendar.component(.hour, from: reminder.date),
                                minute: calendar.component(.minute, from: reminder.date),
                                second: 0,
                                of: occurrenceDate
                            )!
                            
                            let dateKey = createUniqueIDFromDate(date: finalDate)
                            
                            if finalDate >= startDate && finalDate <= endDate &&
                                !seenDates.contains(dateKey) &&
                                (!hideCompleted || !reminder.completedInstances.contains(where: {
                                    Calendar.current.isDate($0, inSameDayAs: finalDate)
                                })) &&
                                !reminder.deletedInstances.contains(where: {
                                    Calendar.current.isDate($0, inSameDayAs: finalDate)
                                }) {
                                
                                seenDates.insert(dateKey)
                                var instanceReminder = reminder
                                instanceReminder.date = finalDate
                                instanceReminder.isComplete = reminder.completedInstances.contains(where: {
                                    Calendar.current.isDate($0, inSameDayAs: finalDate)
                                })
                                
                                expandedData["\(documentID)-\(dateKey)"] = instanceReminder
                            }
                        }
                    }
                    
                    // Move to next month
                    currentMonthDate = calendar.date(byAdding: .month, value: 1, to: currentMonthDate)!
                }
            }
        } else {
            // Standard repeating reminder - always include original if in range (daily/weekly/monthly/yearly)
            
            // Counter used to generate unique instance IDs
            var instanceCount = 0
            
            // Include original reminder if it's in range
            if reminder.date >= startDate && reminder.date <= endDate &&
                (!hideCompleted || !reminder.completedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date)} )) &&
               !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }) {                expandedData["\(documentID)-\(instanceCount)"] = reminder
                instanceCount += 1
                print(reminder.deletedInstances)
            }
            
            // Generate additional instances
            var currentDate = reminder.date
            
            // Generate future instances (up to 50)
            while instanceCount < 50 {
                let nextDate: Date?
                switch repeatType {
                case "Daily":
                    nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate)
                case "Weekly":
                    nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)
                case "Monthly":
                    nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
                case "Yearly":
                    nextDate = calendar.date(byAdding: .year, value: 1, to: currentDate)
                default:
                    nextDate = nil
                }
                
                // Stop if no valid next date
                guard let next = nextDate, next > currentDate else { break }
                currentDate = next
                
                // Check repeat_until_date
                if reminder.repeatSettings.repeat_until_date != "Forever" && !reminder.repeatSettings.repeat_until_date.isEmpty {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy-MM-dd"
                    if let endDateLimit = fmt.date(from: reminder.repeatSettings.repeat_until_date),
                       calendar.startOfDay(for: currentDate) > calendar.startOfDay(for: endDateLimit) {
                        break
                    }
                }
                
                if currentDate > endDate { break }
                if currentDate >= startDate &&
                    (!hideCompleted || !reminder.completedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: currentDate)} )) &&
                   !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: currentDate) }) {
                    var instanceReminder = reminder
                    instanceReminder.date = currentDate
                    instanceReminder.isComplete = reminder.completedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: currentDate) })
                    expandedData["\(documentID)-\(instanceCount)"] = instanceReminder
                    instanceCount += 1
                }
            }
        }
    }
    
    return expandedData
}

func expandRepeatingRemindersForCalendar(userData: [String: ReminderData], startDate: Date, endDate: Date) -> [String: ReminderData] {
    var expandedData: [String: ReminderData] = [:]
    let calendar = Calendar.current
    
    for (documentID, reminder) in userData {
        let repeatType = reminder.repeatSettings.repeat_type
        
        if repeatType == "None" {
            if reminder.date >= startDate && reminder.date <= endDate &&
                !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }){         //HERE----------
                expandedData[documentID] = reminder
            }
            
        } else if repeatType == "Custom" {
            if let intervals = reminder.repeatSettings.repeatIntervals, let daysString = intervals.days {
                let calendar = Calendar.current
                let dayNumbers = daysString
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                
                var seenDates = Set<String>()
                var currentMonthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: reminder.date))!
                
                while currentMonthDate <= endDate && seenDates.count < 200 {
                    let year = calendar.component(.year, from: currentMonthDate)
                    let month = calendar.component(.month, from: currentMonthDate)
                    
                    for day in dayNumbers {
                        var components = DateComponents()
                        components.year = year
                        components.month = month
                        components.day = day
                        
                        if let occurrenceDate = calendar.date(from: components) {
                            let finalDate = calendar.date(
                                bySettingHour: calendar.component(.hour, from: reminder.date),
                                minute: calendar.component(.minute, from: reminder.date),
                                second: 0,
                                of: occurrenceDate
                            )!
                            
                            let dateKey = createUniqueIDFromDate(date: finalDate)
                            
                            if finalDate >= startDate && finalDate <= endDate &&
                                !seenDates.contains(dateKey) &&
                                !reminder.deletedInstances.contains(where: {
                                    Calendar.current.isDate($0, inSameDayAs: finalDate)
                                }) {
                                
                                seenDates.insert(dateKey)
                                var instanceReminder = reminder
                                instanceReminder.date = finalDate
                                
                                expandedData["\(documentID)-\(dateKey)"] = instanceReminder
                            }
                        }
                    }
                    
                    currentMonthDate = calendar.date(byAdding: .month, value: 1, to: currentMonthDate)!
                }
            }
        } else {
            var instanceCount = 0
            
            // Include original reminder if it's in range
            if reminder.date >= startDate && reminder.date <= endDate &&
                !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }) {                 //HERE----------
                expandedData["\(documentID)-\(instanceCount)"] = reminder
                instanceCount += 1
            }
            
            // Generate additional instances
            var currentDate = reminder.date
            
            while instanceCount < 200 {
                let nextDate: Date?
                switch repeatType {
                case "Daily":
                    nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate)
                case "Weekly":
                    nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)
                case "Monthly":
                    nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
                case "Yearly":
                    nextDate = calendar.date(byAdding: .year, value: 1, to: currentDate)
                default:
                    nextDate = nil
                }
                
                guard let next = nextDate, next > currentDate else { break }
                currentDate = next
                
                // Check repeat_until_date
                if reminder.repeatSettings.repeat_until_date != "Forever" && !reminder.repeatSettings.repeat_until_date.isEmpty {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy-MM-dd"
                    if let endDate = fmt.date(from: reminder.repeatSettings.repeat_until_date),
                       calendar.startOfDay(for: currentDate) > calendar.startOfDay(for: endDate) {
                        break
                    }
                }
                
                if currentDate > endDate { break }
                if currentDate >= startDate {
                    let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: currentDate) }
                    if !isDeleted {
                        var instanceReminder = reminder
                        instanceReminder.date = currentDate
                        expandedData["\(documentID)-\(instanceCount)"] = instanceReminder
                        instanceCount += 1
                    }
                }
            }
        }
    }
    
    return expandedData
}

func calculatePatternDateForMonth(pattern: String, month: Date) -> Date? {
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
    
    // Find the nth occurrence of the weekday in this specific month
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
    var occurrenceCount = 0
    
    for day in 1...31 {
        if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
           calendar.component(.month, from: date) == calendar.component(.month, from: month),
           calendar.component(.weekday, from: date) == weekday {
            occurrenceCount += 1
            if occurrenceCount == ordinalNumber {
                return date
            }
        }
    }
    return nil
}
