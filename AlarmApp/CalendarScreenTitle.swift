//
//  CalendarScreenTitle.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 1/4/26.
//

import SwiftUI

// Displays "[firstName]'s Calendar" if caretaker is viewing a senior, otherwise just "Calendar"
struct CalendarScreenTitle: View {
    let firestoreManager: FirestoreManager
    let uidToDisplay: String
    @State private var firstName: String? = nil
    
    var body: some View {
        Group {
            if firestoreManager.isCaretakerViewingSenior, let firstName = firstName, !firstName.isEmpty {
                Text("\(firstName)'s Calendar")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Calendar")
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
