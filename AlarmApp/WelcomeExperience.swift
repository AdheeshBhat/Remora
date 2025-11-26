//
//  WelcomeExperience.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 3/31/25.
//
import SwiftUI

struct WelcomeExperience: View {
    @State private var firstName: String = ""
    let firestoreManager = FirestoreManager()

    var body: some View {
        VStack {
            Text("Welcome \(firstName)!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 1)
            
            Text(getStringFromCurrentDate())
                .font(.title)
                .padding(.bottom)
        }
        .onAppear {
            firestoreManager.getUserFirstName { name in
                if let name = name {
                    DispatchQueue.main.async {
                        firstName = name
                    }
                }
            }
        }
    }
}

