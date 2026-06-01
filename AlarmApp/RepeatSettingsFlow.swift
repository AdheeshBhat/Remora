//
//  RepeatSettingFlow.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/8/25.
//

import SwiftUI

struct RepeatSettingsFlow: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    @Binding var cur_screen: Screen
    @State var title: String
    @Binding var repeatSetting: String
    @State private var localRepeatSetting: String? = nil
    @Binding var repeatUntil: String
    //local repeatUntil var for repeatSettings screen (2nd local)
    @State private var localRepeatScreenRepeatUntil: String
    @Binding var customPatterns: Set<String>
    let firestoreManager: FirestoreManager
    
    
    init(cur_screen: Binding<Screen>, title: String, repeatSetting: Binding<String>, repeatUntil: Binding<String>, customPatterns: Binding<Set<String>>, firestoreManager: FirestoreManager ) {
        self._cur_screen = cur_screen
        self.title = title
        self._repeatSetting = repeatSetting
        self._repeatUntil = repeatUntil
        self._customPatterns = customPatterns
        //local variables
        self._localRepeatSetting = State(initialValue: repeatSetting.wrappedValue)
        self._localRepeatScreenRepeatUntil = State(initialValue: repeatUntil.wrappedValue)
        self.firestoreManager = firestoreManager
    }

    let options = ["None", "Daily", "Weekly", "Monthly", "Yearly", "Custom"]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    //TITLE
                    Text(title)
                        .font(.title)
                        .fontWeight(.medium)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)

                    //"REPEAT" HEADING
                    HStack {
                        Text("Repeat")
                            .foregroundColor(.primary)
                            .font(.headline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.2.circlepath")
                            .foregroundColor(.primary)
                            .padding(.leading, 6)
                    } //HStack ending
                    .frame(maxWidth: .infinity, alignment: .center)

                    //None, Daily, Weekly, Monthly, Yearly, Custom BUTTONS
                    VStack(spacing: 0) {
                        ForEach(options.indices, id: \.self) { index in
                            if options[index] == "Custom" {
                                NavigationLink(destination: CustomRepeatCalendarView(cur_screen: $cur_screen, title: title, repeatSetting: Binding(
                                    get: { localRepeatSetting ?? "None" },
                                    set: { localRepeatSetting = $0 }
                                ), customPatterns: $customPatterns, firestoreManager: firestoreManager)) {
                                    HStack {
                                        Text(options[index])
                                            .foregroundColor(.primary)
                                            .font(.headline)
                                            .fontWeight(.medium)
                                            .padding(.leading, 16)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.primary)
                                            .padding(.trailing, 16)
                                        if (localRepeatSetting == nil && repeatSetting == options[index]) || (localRepeatSetting == options[index]){
                                            Image(systemName: "checkmark")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                                .padding(.trailing, 16)
                                        }
                                    }
                                    .padding(.vertical, 16)
                                }
                            } else {
                                Button(action: {
                                    localRepeatSetting = options[index]
                                }) {
                                    HStack {
                                        Text(options[index])
                                            .foregroundColor(.primary)
                                            .font(.headline)
                                            .fontWeight(.medium)
                                            .padding(.leading, 16)
                                        Spacer()
                                        if (localRepeatSetting == nil && repeatSetting == options[index]) || (localRepeatSetting == options[index]){
                                            Image(systemName: "checkmark")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                                .padding(.trailing, 16)
                                        }
                                    }
                                    .padding(.vertical, 16)
                                }
                            }

                            if index < options.count - 1 {
                                Divider()
                                    .background(Color.blue.opacity(0.3))
                                    .padding(.horizontal, 16)
                            }
                        } //For loop ending
                    } //VStack ending
                    .background(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)

                    
                    //REPEAT UNTIL BUTTON
                    if (localRepeatSetting != "None" && localRepeatSetting != nil) {
                        NavigationLink(destination: RepeatUntilFlow(title: title, cur_screen: $cur_screen, repeatUntil: $localRepeatScreenRepeatUntil, firestoreManager: firestoreManager)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Until")
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Text(localRepeatScreenRepeatUntil)
                                        .foregroundColor(.secondary)
                                        .font(.headline)
                                }
                                .padding(.leading, 16)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.primary)
                                    .padding(.trailing, 16)
                            }
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .padding(.top, 8)
                        }
                    } //if statement ending

                    // DONE BUTTON
                    Button(action: {
                        if localRepeatSetting != nil {
                            repeatSetting = localRepeatSetting!
                            // Clear custom patterns if switching away from Custom
                            if localRepeatSetting != "Custom" {
                                customPatterns.removeAll()
                            }
                        }
                        repeatUntil = localRepeatScreenRepeatUntil
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(.green)
                            .cornerRadius(12)
                    }
                    .padding(.top)

                    Spacer()
                }
                .padding()
            }
            
            VStack {
                NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager).environmentObject(preloadedReminders)
            }
        }
    }
}
