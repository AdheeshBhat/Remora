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

class FirestoreManager: ObservableObject {

    //READING FROM THE DATABASE
    private let db = Firestore.firestore()
    //for caretakers viewing a senior's page
    var currentUID: String?
    @Published var isCaretakerViewingSenior: Bool = false
        
        //MARK: Reminder-relates functions
            //set, get, get for user, update, delete, get forever
    
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
                        //print("Fetched reminder")
                        completion(document)
                    } else {
                        print("Reminder does not exist")
                        completion(nil)
                    }}
                
            }
        }
    }
    
    // Fetch reminders for a user (current user by default, or a specific user by UID)
    func getRemindersForUser(uid: String? = nil, completion: @escaping ([String: ReminderData]?) -> Void) {
        // Determine which UID to use: parameter > currentUID > logged-in user
        let userID = uid ?? currentUID ?? Auth.auth().currentUser?.uid
        
        guard let userID = userID else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        print("Fetching reminders for UID: \(userID)")
        db.collection("users")
            .document(userID)
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
                    let caretakerAlertDelay = data["caretakerAlertDelay"] as? TimeInterval ?? 1800

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
                        isLocked: isLocked,
                        caretakerAlertDelay: caretakerAlertDelay
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
    
    func deleteCurrentUserAccount(completion: @escaping (Result<Void, Error>) -> Void) {
            guard let currentUser = Auth.auth().currentUser else {
                completion(.failure(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is currently logged in."])))
                return
            }
            
            let uid = currentUser.uid
            let userDocRef = db.collection("users").document(uid)
            
            // Delete subcollections first
            let subcollections = ["reminders", "linkedSeniors", "userSettings"]
            let batch = db.batch()
            
            let dispatchGroup = DispatchGroup()
            var deletionError: Error? = nil
            
            for sub in subcollections {
                dispatchGroup.enter()
                userDocRef.collection(sub).getDocuments { snapshot, error in
                    if let error = error {
                        deletionError = error
                        dispatchGroup.leave()
                        return
                    }
                    
                    snapshot?.documents.forEach { doc in
                        batch.deleteDocument(doc.reference)
                    }
                    dispatchGroup.leave()
                }
            }
            
            // Once all subcollections are deleted, delete user document and auth
            dispatchGroup.notify(queue: .main) {
                if let error = deletionError {
                    completion(.failure(error))
                    return
                }
                
                // Delete user document
                batch.deleteDocument(userDocRef)
                
                batch.commit { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    // Delete Firebase Auth user
                    currentUser.delete { authError in
                        if let authError = authError {
                            completion(.failure(authError))
                        } else {
                            completion(.success(()))
                        }
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
                    let caretakerAlertDelay = data["caretakerAlertDelay"] as? TimeInterval ?? 1800
                    
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
                        isLocked: isLocked,
                        caretakerAlertDelay: caretakerAlertDelay
                    )
                    
                    remindersDict[documentID] = reminder
                }
                
                DispatchQueue.main.async { completion(remindersDict) }
            }
    }

        // MARK: User-related functions
            //save data, save settings, load settings, get first name
//-----------------------------------------------------------------------------------------------------------------------------------------------------------
    
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
    
    
    // Gets current user's first name
    func getUserFirstName(completion: @escaping (String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        let userRef = db.collection("users").document(currentUser.uid)
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user first name: \(error)")
                completion(nil)
                return
            }
            if let document = document, document.exists {
                let firstName = document.data()?["firstName"] as? String
                completion(firstName)
            } else {
                completion(nil)
            }
        }
    }
    
    
    func getUsername(completion: @escaping (String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(nil)
            return
        }
        let ref = db.collection("users").document(currentUser.uid)
        ref.getDocument { document, error in
            if let document = document, document.exists {
                completion(document.data()?["username"] as? String)
            } else {
                completion(nil)
            }
        }
    }
    

    
        // MARK: Caretaker-related functions
            // check caretaker, username mapping, get UID, link senior, fetch linked seniors, unlink senior
//-----------------------------------------------------------------------------------------------------------------------------------------------------------
    
    func checkIfCaretaker(completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }

        let userRef = db.collection("users").document(currentUser.uid)
        userRef.getDocument { document, error in
            if let error = error {
                print("Error checking caretaker status: \(error)")
                completion(false)
                return
            }

            if let document = document, document.exists {
                let isCaretaker = document.data()?["isCaretaker"] as? Bool ?? false
                completion(isCaretaker)
            } else {
                completion(false)
            }
        }
    }
    
    // Saves a username-to-UID mapping when user registers
    func saveUsernameMapping(username: String, uid: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("usernameToUID").document(username).setData(["uid": uid]) { error in
            if let error = error {
                print("Error saving username mapping: \(error.localizedDescription)")
            } else {
                print("Saved username mapping for \(username)")
            }
            completion?(error)
        }
    }
    
    // Looks up UID for a given username
    func getUIDFromUsername(username: String, completion: @escaping (String?) -> Void) {
        let ref = db.collection("usernameToUID").document(username)
        ref.getDocument { doc, error in
            if let doc = doc, doc.exists, let data = doc.data(), let uid = data["uid"] as? String {
                completion(uid)
            } else {
                print("Username not found or error: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
            }
        }
    }

    // Links a senior to caretaker
    func linkSeniorToCaretaker(seniorUID: String, seniorUsername: String, completion: ((Error?) -> Void)? = nil) {
        guard let caretaker = Auth.auth().currentUser else {
            completion?(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No caretaker logged in"]))
            return
        }

        let ref = db.collection("users")
            .document(caretaker.uid)
            .collection("linkedSeniors")
            .document(seniorUID)

        ref.setData(["username": seniorUsername]) { error in
            if let error = error {
                print("Error linking senior: \(error.localizedDescription)")
            } else {
                print("Linked senior \(seniorUsername) successfully")
            }
            completion?(error)
        }
    }

    // Fetch linked seniors
    func fetchLinkedSeniors(completion: @escaping ([String]) -> Void) {
        guard let caretaker = Auth.auth().currentUser else {
            completion([])
            return
        }

        db.collection("users").document(caretaker.uid)
            .collection("linkedSeniors")
            .getDocuments { snapshot, error in
                if let docs = snapshot?.documents {
                    let usernames = docs.compactMap { $0.data()["username"] as? String }
                    completion(usernames)
                } else {
                    completion([])
                }
            }
    }
    
    // Unlink a senior from caretaker
    func unlinkSenior(username: String, completion: ((Error?) -> Void)? = nil) {
        guard let caretaker = Auth.auth().currentUser else {
            completion?(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No caretaker logged in"]))
            return
        }
        
        let ref = db.collection("users").document(caretaker.uid).collection("linkedSeniors")
        
        // Find the document with this username
        ref.whereField("username", isEqualTo: username).getDocuments { snapshot, error in
            if let error = error {
                print("Error finding senior to unlink: \(error.localizedDescription)")
                completion?(error)
                return
            }
            
            guard let docs = snapshot?.documents, !docs.isEmpty else {
                print("No senior found with username: \(username)")
                completion?(NSError(domain: "FirebaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No senior found with username"]))
                return
            }
            
            for doc in docs {
                doc.reference.delete { error in
                    if let error = error {
                        print("Error unlinking senior: \(error.localizedDescription)")
                        completion?(error)
                    } else {
                        print("Successfully unlinked senior: \(username)")
                        completion?(nil)
                    }
                }
            }
        }
    }
    
}
