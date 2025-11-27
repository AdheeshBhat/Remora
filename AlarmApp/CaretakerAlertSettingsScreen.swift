//
//  CaretakerAlertSettingsScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 11/26/25.
//

import SwiftUI

struct CaretakerAlertSettingsScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var cur_screen: Screen
    @Binding var selectedDelay: TimeInterval  // bound to EditReminderScreen
    @State var title: String
    let firestoreManager: FirestoreManager
    let reminderID: String
    let onDone: (() -> Void)?

    @State private var tempSelectedDelay: TimeInterval

    private let options: [(label: String, value: TimeInterval)] = [
        ("After 10 mins", 10 * 60),
        ("After 30 mins", 30 * 60),
        ("After 1 hr", 60 * 60),
        ("After 2 hrs", 2 * 60 * 60),
        ("After 4 hrs", 4 * 60 * 60),
        ("After 8 hrs", 8 * 60 * 60)
    ]

    var descriptionText: String {
        "This setting will notify the caretaker if this reminder has not been marked complete after the selected delay from the reminder time."
    }

    init(cur_screen: Binding<Screen>, title: String, selectedDelay: Binding<TimeInterval>, firestoreManager: FirestoreManager, reminderID: String, onDone: (() -> Void)?) {
        self._cur_screen = cur_screen
        self.title = title
        self._selectedDelay = selectedDelay
        self.firestoreManager = firestoreManager
        self.reminderID = reminderID
        self.onDone = onDone
        self._tempSelectedDelay = State(initialValue: selectedDelay.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                //TITLE
                Text(title)
                    .font(.title)
                    .fontWeight(.medium)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(nil)

                //HEADING
                HStack {
                    Text("Caretaker Alert Delay")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Image(systemName: "bell")
                        .foregroundColor(.primary)
                        .padding(.leading, 6)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Options in a single rectangle with dividers
                VStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { index in
                        Button(action: { tempSelectedDelay = options[index].value }) {
                            HStack {
                                Text(options[index].label)
                                    .foregroundColor(.primary)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                                if tempSelectedDelay == options[index].value {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                        }
                        if index < options.count - 1 {
                            Divider()
                                .background(Color.blue.opacity(0.3))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)

                // DESCRIPTION
                Text(descriptionText)
                    .foregroundColor(.secondary)
                    .font(.body)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        
            // Done Button
            Button(action: {
                selectedDelay = tempSelectedDelay
                onDone?()
                cur_screen = .EditScreen
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(Color.green)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }
            Spacer()
            // Bottom nav bar
            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
        }
    }
}
