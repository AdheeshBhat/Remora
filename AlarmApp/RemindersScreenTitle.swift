//
//  RemindersScreenTitle.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 1/4/26.
//

import SwiftUI

// Displays "[firstName]'s Reminders" if caretaker is viewing a senior, otherwise just "Reminders"
struct RemindersScreenTitle: View {
    let firestoreManager: FirestoreManager
    let uidToDisplay: String
    @State private var firstName: String? = nil
    
    var body: some View {
        Group {
            if firestoreManager.isCaretakerViewingSenior, let firstName = firstName, !firstName.isEmpty {
                Text("\(firstName)'s Reminders")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Reminders")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear {
            // Only fetch if caretaker viewing senior
            if firestoreManager.isCaretakerViewingSenior {
                firestoreManager.getUserFirstName(forUID: uidToDisplay) { name in
                    self.firstName = name
                }
            }
        }
    }
}
