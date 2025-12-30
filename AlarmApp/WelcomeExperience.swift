//
//  WelcomeExperience.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 3/31/25.
//
import SwiftUI

import SwiftUI

struct WelcomeExperience: View {
    let uidToDisplay: String
    @State private var firstName: String = ""
    let firestoreManager = FirestoreManager()

    var body: some View {
        VStack {
            if firstName.isEmpty {
                Text("Loading...")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 1)
            } else {
                if firestoreManager.isCaretakerViewingSenior {
                    Text("Viewing \(firstName)'s Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 1)
                } else {
                    Text("Welcome \(firstName)!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 1)
                }
            }
            
            Text(getStringFromCurrentDate())
                .font(.title)
                .padding(.bottom)
        }
        .onAppear {
            firestoreManager.getUserFirstName(forUID: uidToDisplay) { name in
                if let name = name {
                    DispatchQueue.main.async {
                        self.firstName = name
                    }
                }
            }
        }
    }
}
