//
//  DateSelectorScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 8/29/25.
//
import SwiftUI

struct DateSelectorScreen: View {
    let reminderTitle: String
    @Binding var selectedDate: Date
    @Binding var cur_screen: Screen
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    @State private var localSelectedDate: Date
    let firestoreManager: FirestoreManager

    init(reminderTitle: String, selectedDate: Binding<Date>, cur_screen: Binding<Screen>, firestoreManager: FirestoreManager) {
        self.reminderTitle = reminderTitle
        self._selectedDate = selectedDate
        self._cur_screen = cur_screen
        self._localSelectedDate = State(initialValue: selectedDate.wrappedValue)
        self.firestoreManager = firestoreManager
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(reminderTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            DatePicker(
                "Select Date",
                selection: $localSelectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()

            Spacer()

            //DONE BUTTON
            Button(action: {
                selectedDate = localSelectedDate
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
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            cur_screen = .EditScreen
        }
        VStack {
            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager).environmentObject(preloadedReminders)
        }
    } //body ending
}

