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
    if filteredDay != nil {
        startOfDay = calendar.startOfDay(for: filteredDay!)
    }
    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)!
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        return reminderDate >= startOfDay && reminderDate <= endOfDay
    }
}

func filterRemindersForWeek(userData: [Date: ReminderData], filteredDay: Date?) -> [Date: ReminderData] {
    let calendar = Calendar.current
    let today = Date()
    //(start of the week always begins on Sunday in this case) RAISES SAME QUESTION AS FOR MONTH FILTER
    var startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
    if filteredDay != nil {
        startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: filteredDay!))!
    }
    var endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
    endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfWeek)!
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        return reminderDate >= startOfWeek && reminderDate <= endOfWeek
    }
}


//DOES CURRENT MONTH MEAN ex. MAR 1 - MAR 31 or ex. MAR 30 - APR 30?
    //Today's date is at the top of the page, and scroll up/down from MAR 1 - MAR 31, swipe left/right for next/previous month
func filterRemindersForMonth(userData: [Date: ReminderData], filteredDay: Date?) -> [Date: ReminderData] {
    let calendar = Calendar.current
    let today = Date()
    var startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
    if filteredDay != nil {
        startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: filteredDay!))!
    }

    let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
    
    return userData.filter { (_, reminder) in
        let reminderDate = reminder.date
        return reminderDate >= startOfMonth && reminderDate <= endOfMonth
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
    } //VStack ending

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
    } //VStack ending
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
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        default:
            return (today, calendar.date(byAdding: .year, value: 1, to: today)!)
        }
    }()
    
    for (documentID, reminder) in userData {
        let repeatType = reminder.repeatSettings.repeat_type
        
        if repeatType == "None" {
            // Non-repeating reminder
            if reminder.date >= startDate && reminder.date <= endDate {
                expandedData[documentID] = reminder
            }
        } else {
            // Repeating reminder - generate instances
            var currentDate = reminder.date
            var instanceCount = 0
            
            // Find first occurrence in range
            while currentDate < startDate && instanceCount < 1000 {
                switch repeatType {
                case "Daily":
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
                case "Weekly":
                    currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? endDate
                case "Monthly":
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? endDate
                default:
                    currentDate = endDate
                }
                instanceCount += 1
            }
            
            // Generate instances within range
            instanceCount = 0
            while currentDate <= endDate && instanceCount < 50 {
                var instanceReminder = reminder
                instanceReminder.date = currentDate
                expandedData["\(documentID)-\(instanceCount)"] = instanceReminder
                
                // Calculate next occurrence
                let nextDate: Date?
                switch repeatType {
                case "Daily":
                    nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate)
                case "Weekly":
                    nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)
                case "Monthly":
                    nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
                default:
                    nextDate = nil
                }
                
                guard let next = nextDate, next > currentDate else { break }
                currentDate = next
                instanceCount += 1
            }
        }
    }
    
    return expandedData
}
