//
//  Util.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 4/1/25.
//

import SwiftUI


//DATE RELATED FUNCTIONS

func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let created_date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))
    return created_date ?? Date.now
    
}

func createDateFromString(dateString: String) -> Date {
    let format = DateFormatter()
    
    format.dateFormat = "yyyy-MM-dd"
    if let date = format.date(from: dateString) {
        return date
    }
    
    print("Invalid date format.")
    return Date.now
}

//func createExactDateFromText(dateString: String) -> Date {
//    let format = DateFormatter()
//    
//    format.dateFormat = "yyyy-MM-dd HH:mm:ss"
//    if let date = format.date(from: dateString) {
//        return date
//    }
//    
//    print("Invalid date format.")
//    return Date.now
//}
func createExactDateFromString(dateString: String) -> Date {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")!
    
    // Try full timestamp format first
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = formatter.date(from: dateString) {
        return date
    }
    
//    if let isoDate = ISO8601DateFormatter().date(from: dateString) {
//        return isoDate
//    }
    
    // (e.g., Monday, Sep 15)
    formatter.dateFormat = "EEEE, MMM d"
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    // (e.g., Monday, Sep 15 18:44:24)
    formatter.dateFormat = "EEEE, MMM d HH:mm:ss"
    if let date = formatter.date(from: dateString) {
        return date
    }
    
    print("Invalid date format for string: \(dateString), returning current date as fallback")
    return Date.now
}

func createStringFromDate(date: Date) -> String {
    let format = DateFormatter()
    format.dateFormat = "yyyy-MM-dd"
    return format.string(from: date)
}

func createExactStringFromDate(date: Date) -> String {
    let format = DateFormatter()
    format.dateFormat = "EEEE, MMM d HH:mm:ss"
    return format.string(from: date)

}

//UNIQUE ID
func createUniqueIDFromDate(date: Date) -> String {
    let format = DateFormatter()
    format.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return format.string(from: date)
}

//CURRENT
func getExactStringFromCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d HH:mm:ss"
    return formatter.string(from: Date())
}

//CURRENT
func getStringFromCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: Date())
}


//--------------------------------------------------------------------------------------------------------------------------------------------------------


//DATABASE RELATED FUNCTIONS

func getTitle(reminder: ReminderData) -> String {
    return reminder.title
}

func getUserData(cur_database: Database, userID: Int) -> [Date: ReminderData] {
    return cur_database.users[userID] ?? [:]
}

//func getReminderFromDate(userData: [Date: ReminderData], date: Date) -> ReminderData {
//    return userData[date] ?? ReminderData(ID: 1, date: createDate(year: 2025, month: 1, day: 1, hour: 1, minute: 1, second: 1), title: "undefined", description: "1/1/2025", repeatSettings: RepeatSettings(repeat_type: "None", repeat_until_date: "Specific Date"), priority: "Low", isComplete: false, author: "user", isLocked: false)
//}

func getDescriptionFromReminder(reminder: ReminderData) -> String {
    return reminder.description
}

func getDayFromReminder(reminder: ReminderData) -> String {
    let DateFormatter = DateFormatter()
    DateFormatter.dateFormat = "EEEE"
    return DateFormatter.string(from: reminder.date as Date)
}
    
func getTimeFromReminder(reminder: ReminderData) -> String {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: reminder.date)
    let minute = calendar.component(.minute, from: reminder.date)
    var minuteString = String(minute)
    if minute < 10 {
        minuteString = "0" + String(minute)
    }
    return String(hour) + ":" + minuteString
}

func getMonthFromReminder(reminder: ReminderData) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM d"
    return dateFormatter.string(from: reminder.date as Date)
    
}

func getDateFromReminder(reminder: ReminderData) -> Date {
    return reminder.date
}

func getRepeatTypeFromReminder(reminder: ReminderData) -> String {
    return reminder.repeatSettings.repeat_type
}

//
//func getMaxRepeatDateFromReminder(reminder: ReminderData) -> Date {
//    return reminder.repeatSettings.repeat_until_date ?? Date.now
//}



func getRepeatIntervalsFromReminder(reminder: ReminderData) -> CustomRepeatType {
    return reminder.repeatSettings.repeatIntervals ?? CustomRepeatType(days: "Monday", weeks: [0], months: [0])
}


func addToDatabase(database: inout Database, userID: Int, date: Date, reminder: ReminderData) {
    if var userReminders = database.users[userID] {
        userReminders[date] = reminder
        database.users[userID] = userReminders
    } else {
        database.users[userID] = [date: reminder]
    }
}

func deleteFromDatabase(database: inout Database, userID: Int, date: Date) {
    if var userReminders = database.users[userID] {
        userReminders.removeValue(forKey: date)
        database.users[userID] = userReminders
    }
}


//--------------------------------------------------------------------------------------------------------------------------------------------------------

// OTHER

func timeAsDate(_ timeString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "H:mm"
    return formatter.date(from: timeString)
}

func timeAsString(_ time: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "H:mm"
    return formatter.string(from: time)
}

func dayString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
}

func weekString(from date: Date) -> String {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    
    let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
    
    return "\(formatter.string(from: startOfWeek)) – \(formatter.string(from: endOfWeek))"
}

func weekdayFromString(_ day: String) -> Int? {
    let map = [
        "Sun": 1, "Sunday": 1,
        "Mon": 2, "Monday": 2,
        "Tue": 3, "Tuesday": 3,
        "Wed": 4, "Wednesday": 4,
        "Thu": 5, "Thursday": 5,
        "Fri": 6, "Friday": 6,
        "Sat": 7, "Saturday": 7
    ]
    return map[day.capitalized]
}

func monthString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "LLLL"
    return formatter.string(from: date)
}

func yearString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter.string(from: date)
}



