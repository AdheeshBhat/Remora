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

    // The UID of the senior currently being viewed by a caretaker
    // If a caretaker is viewing a senior's page, this is set to the senior's UID
    // Otherwise, it is nil and operations use the logged-in user's UID
    var currentUID: String?
    
    // Flag indicating whether a caretaker is currently viewing a senior's data
    @Published var isCaretakerViewingSenior: Bool = false

    // The UID to use for Firestore operations
    // - If a caretaker is viewing a senior, returns the senior's UID
    // - Otherwise, returns the currently authenticated user's UID
    // - Returns an empty string if no user is logged in
    var activeUserUID: String {
        if isCaretakerViewingSenior, let uid = currentUID {
            return uid
        } else {
            return Auth.auth().currentUser?.uid ?? ""
        }
    }
        
        //MARK: Reminder-related functions
            //set, get, get for user, update, delete, get forever
    
    // Create a reminder
    func setReminder(reminderID: String, reminder: ReminderData, forUIDs: [String]? = nil) {
        let targetUIDs = forUIDs ?? [activeUserUID]
        if targetUIDs.isEmpty { return }

        for uid in targetUIDs {
            do {
                try db.collection("users").document(uid).collection("reminders").document(reminderID).setData(from: reminder)
            } catch {
                print("Failed setReminder for uid \(uid): \(error)")
            }
        }
    }

    // Fetch a reminder
    func getReminder(dateCreated: String, completion: @escaping (DocumentSnapshot?) -> Void) {
        if Auth.auth().currentUser != nil {
            db.collection("users").document(activeUserUID).collection("reminders").document(dateCreated).getDocument { document, error in
                if let document = document, document.exists {
                    completion(document)
                } else {
                    print("Reminder does not exist")
                    completion(nil)
                }
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
                    let creator = data["creator"] as? String ?? author

                    let isComplete = data["isComplete"] as? Bool ?? false
                    let isLocked = data["isLocked"] as? Bool ?? false
                    let caretakerAlertDelay = data["caretakerAlertDelay"] as? TimeInterval ?? 1800
                    let deletedInstances: [Date] = {
                        if let timestamps = data["deletedInstances"] as? [Timestamp] {
                            return timestamps.map {$0.dateValue()}
                        }
                        return []
                    }()
                    let completedInstances: [Date] = {
                        if let timestamps = data["completedInstances"] as? [Timestamp] {
                            return timestamps.map {$0.dateValue()}
                        }
                        return []
                    }()
                    

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
                        creator: creator,
                        isLocked: isLocked,
                        caretakerAlertDelay: caretakerAlertDelay,
                        deletedInstances: deletedInstances,
                        completedInstances: completedInstances
                    )

                    // Use document ID as key instead of date
                    remindersDict[documentID] = reminder
                }

                // return on main thread
                DispatchQueue.main.async { completion(remindersDict) }
            }
    }
    
    func getRemindersForMultipleUsers(uids: [String], completion: @escaping ([String: [String: ReminderData]]) -> Void) {
        var results: [String: [String: ReminderData]] = [:]
        let group = DispatchGroup()

        for uid in uids {
            group.enter()

            getRemindersForUser(uid: uid) { reminders in
                results[uid] = reminders ?? [:]
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    
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

    // Update specific fields of a reminder
    func updateReminderFields(dateCreated: String, fields: [String: Any], completion: @escaping (Bool) -> Void = { _ in }) {
        // activeUID is always the seniorUID
        let activeUID = self.activeUserUID
        
        self.checkIfCaretaker { isCaretaker in
            if isCaretaker {
                let caretakerUID = Auth.auth().currentUser?.uid ?? ""
                let UIDsToUpdate = [caretakerUID, activeUID]
                self.performReminderUpdate(uids: UIDsToUpdate, dateCreated: dateCreated, fields: fields, completion: completion)

            } else {
                self.getLinkedCaretakersForSenior(seniorUID: activeUID) { caretakerUIDs in
                    let UIDsToUpdate = [activeUID] + caretakerUIDs
                    print("UIDsToUpdate: \(UIDsToUpdate)")
                    self.performReminderUpdate(uids: UIDsToUpdate, dateCreated: dateCreated, fields: fields, completion: completion)
                }
            }
        }
    }
    
    private func performReminderUpdate(
        uids: [String],
        dateCreated: String,
        fields: [String: Any],
        completion: @escaping (Bool) -> Void
    ) {

        if uids.isEmpty {
            completion(false)
            return
        }

        let dispatchGroup = DispatchGroup()
        var success = true

        for uid in uids {
            dispatchGroup.enter()

            let docRef = db.collection("users")
                .document(uid)
                .collection("reminders")
                .document(dateCreated)

            docRef.updateData(fields) { error in
                if let error = error {
                    print("Update failed for \(uid): \(error)")
                    success = false
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(success)
        }
    }
    
    // Delete a specific field from a reminder
    func deleteReminderField(field: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if Auth.auth().currentUser != nil {
            db.collection("users").document(activeUserUID).updateData([field: FieldValue.delete()]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    //Delete a reminder document (a whole reminder, with all the fields)
    func deleteReminder(reminderID: String, completion: ((Bool) -> Void)? = nil) {
        
        let activeUID: String = Auth.auth().currentUser?.uid ?? ""
        
        checkIfCaretaker { isCaretaker in
            
            if isCaretaker {
                
                // caretaker deleting → remove from caretaker + the senior currently being viewed
                // currentUID represents the senior whose reminders the caretaker is currently viewing
                let seniorUID = self.currentUID ?? ""
                let uids = [activeUID, seniorUID]
                // DispatchGroup lets us wait until all firestore deletions finish before calling the completion handler
                let group = DispatchGroup()
                
                for uid in uids {
                    group.enter()
                    
                    self.db.collection("users")
                        .document(uid)
                        .collection("reminders")
                        .document(reminderID)
                        .delete { _ in
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
                    completion?(true)
                }
            } else {
                
                // senior deleting → remove from self + all caretakers
                self.getLinkedCaretakersForSenior(seniorUID: activeUID) { caretakerUIDs in
                    
                    let allUIDs = [activeUID] + caretakerUIDs
                    let group = DispatchGroup()
                    
                    for uid in allUIDs {
                        group.enter()
                        
                        self.db.collection("users")
                            .document(uid)
                            .collection("reminders")
                            .document(reminderID)
                            .delete { _ in
                                group.leave()
                            }
                    }
                    
                    group.notify(queue: .main) {
                        completion?(true)
                    }
                }
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
        guard Auth.auth().currentUser != nil else {
            completion(nil)
            return
        }
        db.collection("users")
            .document(activeUserUID)
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
                    let creator = data["creator"] as? String ?? author
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
                        creator: creator,
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
    func getUserFirstName(forUID uid: String, completion: @escaping (String?) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
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
    
    
    // Saves a username-to-UID mapping when user registers
    func saveUsernameMapping(username: String, uid: String, completion: ((Error?) -> Void)? = nil) {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        db.collection("usernameToUID").document(normalized).setData(["uid": uid]) { error in
            if let error = error {
                print("Error saving username mapping: \(error.localizedDescription)")
            } else {
                print("Saved username mapping for \(username)")
            }
            completion?(error)
        }
    }
    
    func ensureUsernameMappingExists() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        getUsername { username in
            guard let username = username else { return }

            let normalized = username.lowercased()

            let ref = Firestore.firestore()
                .collection("usernameToUID")
                .document(normalized)

            ref.getDocument { doc, _ in
                if doc?.exists == true {
                    return // mapping already exists
                }

                ref.setData(["uid": uid]) { error in
                    if let error = error {
                        print("Failed to create username mapping:", error)
                    } else {
                        print("Username mapping created for \(normalized)")
                    }
                }
            }
        }
    }
    
    // Looks up UID for a given username
    func getUIDFromUsername(username: String, completion: @escaping (String?) -> Void) {
        let ref = db.collection("usernameToUID").document(username)
        ref.getDocument { doc, error in
            if let doc = doc, doc.exists,
               let data = doc.data(),
               let uid = data["uid"] as? String {
                completion(uid)
            } else {
                print("Username not found for  username: \(username)")
                completion(nil)
            }
        }
    }
    
    // Fetch linked senior UIDs (document IDs)
    func getLinkedSeniorUIDs(completion: @escaping ([String]) -> Void) {
        guard let caretaker = Auth.auth().currentUser else {
            completion([])
            return
        }

        db.collection("users")
            .document(caretaker.uid)
            .collection("linkedSeniors")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching linked senior UIDs: \(error)")
                    completion([])
                    return
                }

                // documentID == seniorUID
                let seniorUIDs = snapshot?.documents.map { $0.documentID } ?? []
                completion(seniorUIDs)
            }
    }

    // Links a senior to the current caretaker.
    // - Parameters:
    //   - seniorUID: The UID of the senior to link.
    //   - seniorUsername: The username of the senior.
    //   - completion: Optional closure called with error or nil.
    func linkSeniorToCaretaker(seniorUID: String, seniorUsername: String, completion: ((Error?) -> Void)? = nil) {
        guard let caretaker = Auth.auth().currentUser else {
            completion?(NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No caretaker logged in"]))
            return
        }

        let caretakerRef = db.collection("users")
            .document(caretaker.uid)
            .collection("linkedSeniors")
            .document(seniorUID)

        caretakerRef.setData(["username": seniorUsername]) { error in
            if let error = error {
                print("Error linking senior: \(error.localizedDescription)")
            } else {
                print("Linked senior \(seniorUsername) successfully")
            }
            completion?(error)
        }
        
        let seniorRef = db.collection("users").document(seniorUID)
        seniorRef.updateData([
            "LinkedCaretakers": FieldValue.arrayUnion([caretaker.uid])
        ]) { seniorError in
            completion?(seniorError)
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
    
    // Fetches all caretaker UIDs linked to a senior.
    // - Parameters:
    //   - seniorUID: The UID of the senior.
    //   - completion: Closure called with array of caretaker UIDs.
    func getLinkedCaretakersForSenior(seniorUID: String, completion: @escaping ([String]) -> Void) {
        let seniorRef = db.collection("users").document(seniorUID)
        seniorRef.getDocument { document, error in
            if let data = document?.data(), let caretakers = data["LinkedCaretakers"] as? [String] {
                completion(caretakers)
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
    
    // Cancels all local notifications for reminders from a specific senior for the current caretaker
    func cancelAllCaretakerNotificationsFromSenior(seniorUID: String) {
        let caretakerUID = Auth.auth().currentUser?.uid ?? ""
        guard !caretakerUID.isEmpty else { return }

        db
            .collection("users")
            .document(caretakerUID)
            .collection("reminders")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }

                for doc in documents {
                    let data = doc.data()

                    // We rely on author == seniorUID
                    let authorUID = data["author"] as? String ?? ""
                    if authorUID != seniorUID { continue }

                    let reminderID = doc.documentID
                    let baseID = createUniqueIDFromDate(
                        date: createExactDateFromString(dateString: reminderID)
                    )

                    var identifiers: [String] = []

                    // Main notifications
                    for i in 0..<30 {
                        identifiers.append("\(baseID)-\(i)")
                    }

                    // Follow-ups
                    for i in 0..<30 {
                        identifiers.append("\(baseID)-followup-\(i)")
                    }

                    UNUserNotificationCenter.current()
                        .removePendingNotificationRequests(withIdentifiers: identifiers)

                    print("Cancelled caretaker notifications for reminder \(reminderID)")
                }
            }
    }
    
    // MARK: FCM Token Management
    
    // Stores an FCM token for a user in Firestore.
    // - Parameters:
    //   - token: The FCM token string.
    //   - userUID: The UID of the user.
    func storeFCMToken(token: String, for userUID: String) {
        db.collection("users").document(userUID).setData([
            "fcmToken": token,
            "tokenUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("Error storing FCM token: \(error)")
            } else {
                print("FCM token stored successfully for user: \(userUID)")
            }
        }
    }
    
    // Retrieves the FCM token for a user from Firestore
    func getFCMToken(for userUID: String, completion: @escaping (String?) -> Void) {
        db.collection("users").document(userUID).getDocument { document, error in
            if let document = document, document.exists {
                let token = document.data()?["fcmToken"] as? String
                completion(token)
            } else {
                completion(nil)
            }
        }
    }
    
    //Retrieves FCM tokens for multiple users
    func getFCMTokensForUsers(userUIDs: [String], completion: @escaping ([String: String]) -> Void) {
        var tokens: [String: String] = [:]
        let dispatchGroup = DispatchGroup()
        
        for uid in userUIDs {
            dispatchGroup.enter()
            getFCMToken(for: uid) { token in
                if let token = token {
                    tokens[uid] = token
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(tokens)
        }
    }
    
}
