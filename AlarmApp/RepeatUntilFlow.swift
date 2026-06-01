//
//  RepeatUntilFlow.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/8/25.
//



import SwiftUI

struct RepeatUntilFlow: View {
    var title: String = "New Reminder"
    @Binding var cur_screen: Screen
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    @State var selectedDate: Date = Date()
    @Binding var repeatUntil: String
    @State private var repeatUntilOptionSelected: String
    let firestoreManager: FirestoreManager
    //define a string variable to use to check if specific date is pressed
    
    
    init(title: String, cur_screen: Binding<Screen>, repeatUntil: Binding<String>, firestoreManager: FirestoreManager) {
        self.title = title
        self._cur_screen = cur_screen
        self._repeatUntil = repeatUntil
        self._repeatUntilOptionSelected = State(initialValue: "")
        
        if repeatUntil.wrappedValue != "Forever" {
            self._selectedDate = State(initialValue: createDateFromString(dateString: repeatUntil.wrappedValue))
        } else {
            self._selectedDate = State(initialValue: Date())
        }
        
        self.firestoreManager = firestoreManager
    }

    var options = ["Forever", "Specific Date"]
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack(spacing: 20) {
                    // TITLE
                    Text(title)
                        .font(.title)
                        .fontWeight(.medium)
                        .padding(.top)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // OPTIONS LIST
                    VStack(spacing: 0) {
                        ForEach(options, id: \.self) { option in
                            Button(action: {
                                repeatUntilOptionSelected = option
                            }) {
                                HStack {
                                    Text(option)
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .padding(.leading, 16)
                                    Spacer()
                                    if repeatUntilOptionSelected == option {
                                        Image(systemName: "checkmark")
                                            .font(.title2)
                                            .foregroundColor(.green)
                                            .padding(.trailing, 16)
                                    }
                                }
                                .padding(.vertical, 16)
                            }
                            if option != options.last {
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
                    .padding(.horizontal)

                    // CALENDAR
                    if repeatUntilOptionSelected == "Specific Date" {
                        DatePicker(
                            "Select Date",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                } // VStack inside ScrollView
            } // ScrollView ending
            
            // DONE BUTTON
            Button(action: {
                if repeatUntilOptionSelected == "Specific Date" {
                    repeatUntil = createStringFromDate(date: selectedDate)
                } else {
                    repeatUntil = repeatUntilOptionSelected
                }
                
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            .onAppear {
                if repeatUntil == "Forever" {
                    repeatUntilOptionSelected = repeatUntil
                } else {
                    repeatUntilOptionSelected = "Specific Date"
                    selectedDate = createDateFromString(dateString: repeatUntil)
                }
            }

            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager).environmentObject(preloadedReminders)
        }
    }
}


