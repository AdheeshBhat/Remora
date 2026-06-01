//
//  CreateReminderButton.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 5/28/25.
//

import SwiftUI

struct CreateReminderExperience: View {
    @Binding var cur_screen: Screen
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    let firestoreManager: FirestoreManager

    var body: some View {
        NavigationLink(destination: CreateReminderScreen(cur_screen: $cur_screen, firestoreManager: firestoreManager).environmentObject(preloadedReminders)) {
            Image(systemName: "plus")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(10)
                .background(Circle().fill(Color.blue))
        }
        .padding(.trailing) 
    }
}
