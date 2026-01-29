//
//  RescheduleAllNotifications.swift
//  AlarmApp
//
//  Created by Mohsen, Yousif on 1/25/26.
//

import Foundation

func rescheduleAllNotificationsForUser() {
    let firestoreManager = FirestoreManager()

    firestoreManager.checkIfCaretaker { isCaretakerAccount in
        firestoreManager.getRemindersForUser { reminders in
            guard let reminders = reminders else { return }

            firestoreManager.loadUserSettings(field: "selectedSound") { soundValue in
                let soundType = (soundValue as? String) ?? "Chord"

                for (documentID, reminder) in reminders {
                    if reminder.isComplete { continue }

                    // 🚨 KEY FIX: role decided BEFORE scheduling
                    setAlarm(
                        dateAndTime: reminder.date,
                        title: reminder.title,
                        description: reminder.description,
                        repeat_type: reminder.repeatSettings.repeat_type,
                        repeat_until_date: reminder.repeatSettings.repeat_until_date,
                        repeatIntervals: reminder.repeatSettings.repeatIntervals,
                        reminderID: documentID,
                        soundType: soundType,
                        caretakerAlertDelay: reminder.caretakerAlertDelay,
                        isCaretakerNotification: isCaretakerAccount,
                        seniorName: reminder.author
                    )
                }

                print("Rescheduled \(reminders.count) reminders for current user")
            }
        }
    }
}
