//
//  Firebase.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 9/7/25.
//

import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

//struct Reminder: Codable {
//    var ID: Int
//    var author: String
//    var date: Date
//    var description: String
//    var isComplete: Bool
//    var isLocked: Bool
//    var priority: String
//    //var repeatSettings: RepeatSettings
//    var title: String
//}

class FirestoreManager {

    //READING FROM THE DATABASE
    private let db = Firestore.firestore()
        
    // Create a reminder
    func setReminder(reminderID: String, reminder: ReminderData) {
        if let currentUser = Auth.auth().currentUser {
            do {
                //try db.collection("users").document(currentUser.uid).collection("reminders").document(getExactStringFromCurrentDate()).setData(from: reminder)
                try db.collection("users").document(currentUser.uid).collection("reminders").document(reminderID).setData(from: reminder)
                
            } catch {
                print("Failed setReminder")
            }
        }

        
    }

    // Fetch a reminder
    
    func getReminder(dateCreated: String, completion: @escaping (DocumentSnapshot?) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            do {
                db.collection("users").document(currentUser.uid).collection("reminders").document(dateCreated).getDocument { document, error in
                    if let document = document, document.exists {
                        print("Fetched reminder")
                        completion(document)
                    } else {
                        print("Reminder does not exist")
                        completion(nil)
                    }}
                
            }
        }
    }
    

    func getRemindersForUser(completion: @escaping ([String: ReminderData]?) -> Void) {
        // ensures that the user is logged in
        guard let currentUser = Auth.auth().currentUser else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        db.collection("users")
          .document(currentUser.uid)
          .collection("reminders")
          .getDocuments { querySnapshot, error in
              // if Firestore query fails
              if let error = error {
                  print("Error fetching reminders for user: \(error)")
                  DispatchQueue.main.async { completion(nil) }
                  return
              }
              //case where no documents exist
              guard let documents = querySnapshot?.documents else {
                  print("Reminders for user does not exist")
                  DispatchQueue.main.async { completion([:]) } // empty dict
                  return
              }

              var remindersDict: [String: ReminderData] = [:]
              
              //loops through every reminder document
              for doc in documents {
                  let data = doc.data()
                  let documentID = doc.documentID

                  // ID
                  let id: Int = {
                      if let v = data["ID"] as? Int { return v }
                      return 0
                  }()

                  let title = data["title"] as? String ?? ""
                  let description = data["description"] as? String ?? ""
                  let priority = data["priority"] as? String ?? "Low"
                  let author = data["author"] as? String ?? "user"

                  let isComplete = data["isComplete"] as? Bool ?? false
                  let isLocked = data["isLocked"] as? Bool ?? false

                  let dateFromField: Date? = {
                      if let ts = data["date"] as? Timestamp {
                          return ts.dateValue()
                      }
                      return nil
                  }()

                  // repeatSettings
                  let repeatSettings: RepeatSettings = {
                      if let rsMap = data["repeatSettings"] as? [String: Any] {
                          let repeatType = rsMap["repeat_type"] as? String ?? (data["repeat_type"] as? String ?? "None")
                          let repeatUntil = rsMap["repeat_until_date"] as? String ?? (data["repeat_until_date"] as? String ?? "")
                          
                          // Load repeatIntervals
                          let repeatIntervals: CustomRepeatType? = {
                              if let intervalsMap = rsMap["repeatIntervals"] as? [String: Any] {
                                  let days = intervalsMap["days"] as? String
                                  let weeks = intervalsMap["weeks"] as? [Int]
                                  let months = intervalsMap["months"] as? [Int]
                                  return CustomRepeatType(days: days, weeks: weeks, months: months)
                              }
                              return nil
                          }()
                          
                          return RepeatSettings(repeat_type: repeatType, repeat_until_date: repeatUntil, repeatIntervals: repeatIntervals)
                      } else {
                          let repeatType = data["repeat_type"] as? String ?? "None"
                          let repeatUntil = data["repeat_until_date"] as? String ?? ""
                          return RepeatSettings(repeat_type: repeatType, repeat_until_date: repeatUntil)
                      }
                  }()

                  // Build ReminderData (matches your initializer)
                  let reminder = ReminderData(
                      ID: id,
                      date: dateFromField ?? Date(),
                      title: title,
                      description: description,
                      repeatSettings: repeatSettings,
                      priority: priority,
                      isComplete: isComplete,
                      author: author,
                      isLocked: isLocked
                  )

                  // Use document ID as key instead of date
                  remindersDict[documentID] = reminder
              }

              // return on main thread
              DispatchQueue.main.async { completion(remindersDict) }
          }
    }
    

    // Update specific fields of a reminder
    func updateReminderFields(dateCreated: String, fields: [String: Any], completion: @escaping (Bool) -> Void = { _ in }) {
        if let currentUser = Auth.auth().currentUser {
            let docRef = db.collection("users").document(currentUser.uid).collection("reminders").document(dateCreated)
            
            docRef.getDocument { document, error in
                if let document = document, document.exists {
                    docRef.updateData(fields) { error in
                        if let error = error {
                            print("ERROR: Update failed: \(error)")
                            completion(false)
                        } else {
                            print("SUCCESS: Document updated")
                            completion(true)
                        }
                    }
                } else {
                    print("ERROR: Document '\(dateCreated)' does not exist")
                    completion(false)
                }
            }
        } else {
            completion(false)
        }
    }

    
    func saveUserData(userId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            db.collection("users").document(currentUser.uid).setData(data) { error in
                completion(error)
            }
        }
        
    }
    
    func saveUserSettings(field: String, value: Any, completion: ((Error?) -> Void)? = nil) {
        if let currentUser = Auth.auth().currentUser {
            let settingsRef = db.collection("users").document(currentUser.uid).collection("userSettings").document("userSettings")
            settingsRef.setData([field: value], merge: true) {error in
                if let error = error {
                    print("Error saving user setting: \(error)")
                } else {
                    print("Saved \(field) = \(value)")
                }
            completion?(error)}
        }
    }
    
    func loadUserSettings(field: String, completion: @escaping (Any?) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            let settingsRef = db
                .collection("users")
                .document(currentUser.uid)
                .collection("userSettings")
                .document("userSettings")

            settingsRef.getDocument { document, error in
                if let document = document, document.exists,
                   let value = document.data()?[field] {
                    completion(value)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // Delete a specific field from a reminder
    func deleteReminderField(field: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            db.collection("users").document(currentUser.uid).updateData([field: FieldValue.delete()]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
        
    }
    
    //Delete a reminder document (a whole reminder, with all the fields)
    func deleteReminder(dateCreated: String, completion: ((Error?) -> Void)? = nil) {
        if let currentUser = Auth.auth().currentUser {
            db.collection("users").document(currentUser.uid).collection("reminders").document(dateCreated).delete { error in
                if let error = error {
                    print("Error deleting reminder: \(error)")
                } else {
                    print("Reminder deleted successfully")
                    print(dateCreated)
                }
                completion?(error)
            }
        }
    }

//    // Delete a reminder document
//    func deleteReminderDocument(userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
//        db.collection("reminder").document(userID).delete { error in
//            if let error = error {
//                completion(.failure(error))
//            } else {
//                completion(.success(()))
//            }
//        }
//    }
    
    // Delete a reminder collection
    //Can't delete the actual collection - instead deletes everything inside (all documents and fields)
    func deleteReminderCollection(collection: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let collectionRef = db.collection(collection)
        
        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success(())) // nothing to delete
                return
            }
            
            let batch = self.db.batch()
            
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // Get all forever repeating reminders for refreshing notifications
    func getForeverReminders(completion: @escaping ([String: ReminderData]?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        
        db.collection("users")
            .document(currentUser.uid)
            .collection("reminders")
            .whereField("repeatSettings.repeat_until_date", isEqualTo: "Forever")
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error fetching forever reminders: \(error)")
                    completion(nil)
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    completion([:])
                    return
                }
                
                var remindersDict: [String: ReminderData] = [:]
                
                for doc in documents {
                    let data = doc.data()
                    let documentID = doc.documentID
                    
                    // Parse reminder data (same as getRemindersForUser)
                    let id = data["ID"] as? Int ?? 0
                    let title = data["title"] as? String ?? ""
                    let description = data["description"] as? String ?? ""
                    let priority = data["priority"] as? String ?? "Low"
                    let author = data["author"] as? String ?? "user"
                    let isComplete = data["isComplete"] as? Bool ?? false
                    let isLocked = data["isLocked"] as? Bool ?? false
                    
                    let dateFromField: Date?
                    if let ts = data["date"] as? Timestamp {
                        dateFromField = ts.dateValue()
                    } else {
                        dateFromField = nil
                    }
                    
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
                    
                    let reminder = ReminderData(
                        ID: id,
                        date: dateFromField ?? Date(),
                        title: title,
                        description: description,
                        repeatSettings: repeatSettings,
                        priority: priority,
                        isComplete: isComplete,
                        author: author,
                        isLocked: isLocked
                    )
                    
                    remindersDict[documentID] = reminder
                }
                
                DispatchQueue.main.async { completion(remindersDict) }
            }
    }
}


class ReminderViewModel: ObservableObject {
    private let firestoreManager = FirestoreManager()
    
//    func addTestReminder() {
//        let reminder = ReminderData(
//            ID: 1,
//            author: "Yousif",
//            date: Date(),
//            description: "description",
//            repeatSettings:
//            isComplete: true,
//            isLocked: true,
//            priority: "Low",
//            title: "Test Reminder"
//        )
//        firestoreManager.setReminder(userID: "user123", reminder: reminder) { result in
//            print(result)
//        }
//    }

//    func testGetReminder() {
//        firestoreManager.getReminder(userID: "user123") { result in
//            switch result {
//            case .success(let reminder):
//                print("Fetched reminder: \(reminder)")
//            case .failure(let error):
//                print("Error fetching reminder: \(error)")
//            }
//        }
//    }

//    func testUpdateReminderFields() {
//        firestoreManager.updateReminderFields(userID: "user123", fields: ["title": "test title"]) { result in
//            switch result {
//            case .success:
//                print("Successfully updated fields")
//            case .failure(let error):
//                print("Error updating fields: \(error)")
//            }
//        }
//    }

//    func testDeleteReminderField() {
//        firestoreManager.deleteReminderField(userID: "user123", field: "newField") { result in
//            switch result {
//            case .success:
//                print("Successfully deleted field 'priority'")
//            case .failure(let error):
//                print("Error deleting field: \(error)")
//            }
//        }
//    }
    

//    func testDeleteReminderDocument() {
//        firestoreManager.deleteReminderDocument(userID: "user123") { result in
//            switch result {
//            case .success:
//                print("Successfully deleted reminder document")
//            case .failure(let error):
//                print("Error deleting reminder: \(error)")
//            }
//        }
//    }
    
    //Can't delete the actual collection - instead deletes everything inside (all documents and fields)
    func testDeleteReminderCollection() {
        firestoreManager.deleteReminderCollection(collection: "testDeleteCollection") { result in
            switch result {
            case .success:
                print("Successfully deleted reminder collection")
            case .failure(let error):
                print("Error deleting reminder: \(error)")
            }
        }
    }
}

struct TestRemindersView: View {
    @State private var reminders: [String: ReminderData] = [:]
    private let firestoreManager = FirestoreManager()
    
    var body: some View {
        VStack {
            Text("Reminders Test")
                .font(.title)
            
            List {
                ForEach(reminders.sorted(by: { $0.value.date < $1.value.date }), id: \.key) { (documentID, reminder) in
                    VStack(alignment: .leading) {
                        Text(reminder.title)
                            .font(.headline)
                        Text("Date: \(reminder.date)")
                        Text("Complete: \(reminder.isComplete ? "Yes" : "No")")
                        Text("ID: \(documentID)")
                    }
                }
            }
        }
        .onAppear {
            firestoreManager.getRemindersForUser { fetchedReminders in
                if let fetchedReminders = fetchedReminders {
                    print("Fetched \(fetchedReminders.count) reminders:")
                    for (documentID, reminder) in fetchedReminders {
                        print("DocumentID: \(documentID), Title: \(reminder.title), Complete: \(reminder.isComplete)")
                    }
                    reminders = fetchedReminders
                } else {
                    print("No reminders fetched")
                }
            }
        }
    }
}
