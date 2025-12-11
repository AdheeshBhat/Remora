//
//  FilteringReminders.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 6/17/25.
//

import SwiftUI

// ↓ REMINDER FILTERS ↓

func filterRemindersForToday(userData: [Date: ReminderData], filteredDay: Date?) -> [Date: ReminderData] {
    let calendar = Calendar.current
    let today = Date()
    var startOfDay = calendar.startOfDay(for: today)
    if let filteredDay = filteredDay {
        startOfDay = calendar.startOfDay(for: filteredDay)
    }
    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)!
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate) }
        print("deletedInstances in reminder struct: \(reminder.deletedInstances)")
        return reminderDate >= startOfDay && reminderDate <= endOfDay && !isDeleted
    }
}

func filterRemindersForWeek(userData: [Date: ReminderData], filteredDay: Date?) -> [Date: ReminderData] {
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
        let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate) }
        return reminderDate >= startOfWeek && reminderDate <= endOfWeek && !isDeleted
    }
}


//DOES CURRENT MONTH MEAN ex. MAR 1 - MAR 31 or ex. MAR 30 - APR 30?
    //Today's date is at the top of the page, and scroll up/down from MAR 1 - MAR 31, swipe left/right for next/previous month
func filterRemindersForMonth(userData: [Date: ReminderData], filteredDay: Date?) -> [Date: ReminderData] {
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
        let isDeleted = reminder.deletedInstances.contains { Calendar.current.isDate($0, inSameDayAs: reminderDate) }
        return reminderDate >= startOfMonth && reminderDate <= inclusiveEndOfMonth && !isDeleted
    }
}

//--------------------------------------------------------------- 1

//Returns reminders based on day, week, or month filter
func showAllReminders(userID: Int, period: String, cur_screen: Binding<Screen>, showEditButton: Bool = false, showDeleteButton: Bool = false, filteredDay: Date?, firestoreManager: FirestoreManager, userData: [Date: ReminderData]) -> some View {
    //let userData = database.wrappedValue.users[userID] ?? [:]
    
    let filteredUserData: [Date: ReminderData]
    if period == "today" {
        filteredUserData = filterRemindersForToday(userData: userData, filteredDay: filteredDay)
    } else if period == "week" {
        filteredUserData = filterRemindersForWeek(userData: userData, filteredDay: filteredDay)
    } else if period == "month" {
        filteredUserData = filterRemindersForMonth(userData: userData, filteredDay: filteredDay)
    } else {
        filteredUserData = userData
    }
    
    let dateFormatter = DateFormatter()
        //can change to .short, .medium, or .long format
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    
    return VStack {
        ForEach(filteredUserData.keys.sorted(), id: \.self) { date in
            if let reminder = filteredUserData[date] {
                HStack {
                    ReminderRow(
                        cur_screen: cur_screen,
                        title: getTitle(reminder: reminder),
                        time: getTimeFromReminder(reminder: reminder),
                        reminderDate: getDayFromReminder(reminder: reminder),
                        reminder: reminder,
                        showEditButton: showEditButton,
                        showDeleteButton: showDeleteButton,
                        userID: userID,
                        dateKey: date,
                        documentID: createExactStringFromDate(date: date),
                        firestoreManager: firestoreManager,
                        onUpdate: nil
                    )
                    
                    //Show past reminders that have already been completed
                    
                } //HStack ending
                //.padding()
            }// if statement ending
        } //ForEach() ending
    }

}

//----------------------------------------------------------------- 2


func showIncompleteReminders(userID: Int, period: String, cur_screen: Binding<Screen>, showEditButton: Bool = false, showDeleteButton: Bool = false, filteredDay: Date?, firestoreManager: FirestoreManager, userData: [Date: ReminderData]) -> some View {
    //let userData = database.wrappedValue.users[userID] ?? [:]
    
    let filteredUserData: [Date: ReminderData]
    if period == "today" {
        filteredUserData = filterRemindersForToday(userData: userData, filteredDay: filteredDay)
    } else if period == "week" {
        filteredUserData = filterRemindersForWeek(userData: userData, filteredDay: filteredDay)
    } else if period == "month" {
        filteredUserData = filterRemindersForMonth(userData: userData, filteredDay: filteredDay)
    } else {
        filteredUserData = userData
    }
    
    let dateFormatter = DateFormatter()
        //can change to .short, .medium, or .long format
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

    //let incompleteReminders = filteredUserData.filter { $0.value.isComplete != true }

    return VStack {
        ForEach(filteredUserData.keys.sorted(), id: \.self) { date in
            if let reminder = filteredUserData[date], reminder.isComplete != true {
                HStack {

                    ReminderRow(
                        cur_screen: cur_screen,
                        title: getTitle(reminder: reminder),
                        time: getTimeFromReminder(reminder: reminder),
                        reminderDate: getDayFromReminder(reminder: reminder),
                        reminder: reminder,
                        showEditButton: showEditButton,
                        showDeleteButton: showDeleteButton,
                        userID: userID,
                        dateKey: date,
                        documentID: createExactStringFromDate(date: date),
                        firestoreManager: firestoreManager,
                        onUpdate: nil
                    ) //ReminderRow ending
                } //HStack ending
                //.padding()
            } // if statement ending
        } //ForEach() ending
    }
}


//----------------------------------------------------------------- 3


func formattedReminders(userID: Int, period: String, cur_screen: Binding<Screen>, showEditButton: Bool = true, showDeleteButton: Bool = false, filteredDay: Date?, firestoreManager: FirestoreManager, userData: [String: ReminderData], onUpdate: (() -> Void)? = nil) -> some View {
    
    let expandedReminders = expandRepeatingReminders(userData: userData, period: period, filteredDay: filteredDay)
    let sortedReminders = expandedReminders.sorted { $0.value.date < $1.value.date }
    
    return VStack {
        ForEach(sortedReminders, id: \.key) { (documentID, reminder) in
            HStack {
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

func expandRepeatingReminders(userData: [String: ReminderData], period: String, filteredDay: Date?) -> [String: ReminderData] {
    var expandedData: [String: ReminderData] = [:]
    let calendar = Calendar.current
    
    // Determine date range based on period
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
    
    for (documentID, reminder) in userData {
        let repeatType = reminder.repeatSettings.repeat_type
        
        if repeatType == "None" {
            // Non-repeating reminder
            if reminder.date >= startDate && reminder.date <= endDate &&
               !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }) {
                expandedData[documentID] = reminder
                
            }
        } else if repeatType == "Custom" {
            // Handle custom patterns differently - generate all occurrences in range
            if let intervals = reminder.repeatSettings.repeatIntervals, let daysString = intervals.days {
                let patterns = daysString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                var seenDates = Set<String>()
                
                // Include original reminder if it's in range
                if reminder.date >= startDate && reminder.date <= endDate &&
                   !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }) {                    expandedData[documentID] = reminder
                }
                
                // Generate occurrences for each month in range, starting from next month after original
                let originalMonth = calendar.dateComponents([.year, .month], from: reminder.date)
                let startMonth = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: originalMonth)!) ?? reminder.date
                var currentMonth = calendar.dateComponents([.year, .month], from: startMonth)
                let endMonth = calendar.dateComponents([.year, .month], from: endDate)
                
                while (currentMonth.year! < endMonth.year! || (currentMonth.year! == endMonth.year! && currentMonth.month! <= endMonth.month!)) && seenDates.count < 50 {
                    let monthStart = calendar.date(from: currentMonth)!
                    
                    for pattern in patterns {
                        if let occurrenceDate = calculatePatternDateForMonth(pattern: pattern, month: monthStart) {
                            let finalDate = calendar.date(bySettingHour: calendar.component(.hour, from: reminder.date), minute: calendar.component(.minute, from: reminder.date), second: 0, of: occurrenceDate)!
                            let dateKey = createUniqueIDFromDate(date: finalDate)

                            if finalDate >= startDate && finalDate <= endDate &&
                               !seenDates.contains(dateKey) &&
                               !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: finalDate) }) {                                seenDates.insert(dateKey)
                                var instanceReminder = reminder
                                instanceReminder.date = finalDate
                                expandedData["\(documentID)-\(dateKey)"] = instanceReminder
                            }
                        }
                    }
                    
                    currentMonth.month! += 1
                    if currentMonth.month! > 12 {
                        currentMonth.month = 1
                        currentMonth.year! += 1
                    }
                }
            }
        } else {
            // Standard repeating reminder - always include original if in range
            var instanceCount = 0
            
            // Include original reminder if it's in range
            if reminder.date >= startDate && reminder.date <= endDate &&
               !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }) {                expandedData["\(documentID)-\(instanceCount)"] = reminder
                instanceCount += 1
                print(reminder.deletedInstances)
            }
            
            // Generate additional instances
            var currentDate = reminder.date
            
            // Generate future instances
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
                   !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: currentDate) }) {
                    var instanceReminder = reminder
                    instanceReminder.date = currentDate
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
                let patterns = daysString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                var seenDates = Set<String>()
                
                // Include original reminder if it's in range
                if reminder.date >= startDate && reminder.date <= endDate &&
                    !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: reminder.date) }){         //HERE----------
                    expandedData[documentID] = reminder
                }
                
                let originalMonth = calendar.dateComponents([.year, .month], from: reminder.date)
                let startMonth = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: originalMonth)!) ?? reminder.date
                var currentMonth = calendar.dateComponents([.year, .month], from: startMonth)
                let endMonth = calendar.dateComponents([.year, .month], from: endDate)
                
                while (currentMonth.year! < endMonth.year! || (currentMonth.year! == endMonth.year! && currentMonth.month! <= endMonth.month!)) && seenDates.count < 200 {
                    let monthStart = calendar.date(from: currentMonth)!
                    
                    for pattern in patterns {
                        if let occurrenceDate = calculatePatternDateForMonth(pattern: pattern, month: monthStart) {
                            let finalDate = calendar.date(bySettingHour: calendar.component(.hour, from: reminder.date), minute: calendar.component(.minute, from: reminder.date), second: 0, of: occurrenceDate)!
                            let dateKey = createUniqueIDFromDate(date: finalDate)
                            
                            if finalDate >= startDate && finalDate <= endDate && !seenDates.contains(dateKey) &&
                                !reminder.deletedInstances.contains(where: { Calendar.current.isDate($0, inSameDayAs: finalDate) }){     //HERE----------
                                seenDates.insert(dateKey)
                                var instanceReminder = reminder
                                instanceReminder.date = finalDate
                                expandedData["\(documentID)-\(dateKey)"] = instanceReminder
                            }
                        }
                    }
                    
                    currentMonth.month! += 1
                    if currentMonth.month! > 12 {
                        currentMonth.month = 1
                        currentMonth.year! += 1
                    }
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
