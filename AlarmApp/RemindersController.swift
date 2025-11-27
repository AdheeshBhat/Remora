//
//  Constants.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 2/18/25.
//
import SwiftUI


struct CustomRepeatType: Codable, Equatable {
    var days: String?
    //Weeks: [1 (every week), 2 (every 2 weeks), 3]
    //Months:  [1-13] (13 means all months are enabled)
    var weeks: [Int]?
    var months: [Int]?
    
    init(days: String? = nil, weeks: [Int]? = nil, months: [Int]? = nil, ID: Int? = nil, userData: [Date: ReminderData]? = nil) {
        self.days = days
        self.weeks = weeks
        self.months = months

    }
}

//UPDATE REPEAT SETTINGS TO HAVE PRIORITY
    //TEXTBOX for
struct RepeatSettings: Codable, Equatable {
    var repeat_type: String //(None, daily, monthly, etc)
    var repeat_until_date: String // should match date field s (STRING IS TEMPORARY - CHANGE BACK TO DATE LATER)
    var repeatIntervals: CustomRepeatType?
    
    
    init(repeat_type: String, repeat_until_date: String, repeatIntervals: CustomRepeatType? = nil) {
        self.repeat_type = repeat_type
        self.repeatIntervals = repeatIntervals
        self.repeat_until_date = repeat_until_date
    }
    
}

struct ReminderData: Codable, Equatable {
    var title: String
    var ID: Int
    var date: Date
    var description: String
    var repeatSettings: RepeatSettings
    var priority: String    //Low or High
    var isComplete: Bool    //true = complete
    var author: String      //"user" or "caregiver"
    var isLocked: Bool      //true = locked
    var caretakerAlertDelay: TimeInterval
    
    init(ID: Int, date: Date, title: String, description: String, repeatSettings: RepeatSettings, priority: String, isComplete: Bool, author: String, isLocked: Bool, caretakerAlertDelay: TimeInterval) {
        self.ID = ID
        self.date = date
        self.title = title
        self.description = description
        self.repeatSettings = repeatSettings
        self.priority = priority
        self.isComplete = isComplete
        self.author = author
        self.isLocked = isLocked
        self.caretakerAlertDelay = caretakerAlertDelay
    }
}



struct Database {
    var users: [Int: [Date: ReminderData]]
    
    init(users: [Int: [Date: ReminderData]]) {
        self.users = users
    }
    
}


struct userSettings {
    var selectedSound: String
    
    init(selectedSound: String) {
        self.selectedSound = selectedSound
    }
}


//    struct RepeatSettings: {
//        Repeat_type: string (None, daily, monthly, etc)
//        Repeat_until_date: integer // should match date field s
//        Struct CustomRepeatType {
//            Days: M,W,F
//            Weeks: [1 (every week), 2 (every 2 weeks), 3]
//            Months:  [1-13] (13 means all months are enabled)
//            }
//        }

//    Priority:
//    String (Low: False, High: True)
//
//    Status: Complete/incomplete (boolean)
//    Author: string (caregiver or user)
//    Lock Status: Locked/unlocked (boolean)

