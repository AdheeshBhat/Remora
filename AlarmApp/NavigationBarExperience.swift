//
//  NavigationBarExperience.swift
//  Alarm App
//
//  Created by Adheesh Bhat on 3/31/25.
//

import SwiftUI

struct NavigationBarExperience: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appearance: AppearanceModel
    
    @Binding var cur_screen: Screen
    @ObservedObject var firestoreManager: FirestoreManager
    @StateObject private var keyboard = KeyboardObserver()
    @State private var initialCalendarViewType: String = "month"
    
    var body: some View {
        VStack {
            VStack {
                Rectangle()
                    .frame(maxWidth: .infinity, maxHeight: 2)
                
            }
            //.padding(.top, 300)
            
            HStack(spacing: 60) {
                
                //REMINDERS BUTTON
                VStack() {
                    if cur_screen != .RemindersScreen {
                        if appearance.defaultToCalendarView {
                            NavigationLink(
                                destination: CalendarView(
                                    cur_screen: $cur_screen,
                                    initialViewType: $initialCalendarViewType,
                                    firestoreManager: firestoreManager
                                )
                                .environmentObject(appearance)
                            ) {
                                Image(systemName: "list.bullet")
                                    .font(.title)
                                    .padding(7)
                                    .foregroundColor((cur_screen == .RemindersScreen) ? Color.blue : Color.primary)
                            }
                        } else {
                            NavigationLink(
                                destination: RemindersScreen(
                                    cur_screen: $cur_screen,
                                    filterPeriod: "week",
                                    remindersForUser: [:],
                                    firestoreManager: firestoreManager
                                )
                            ) {
                                Image(systemName: "list.bullet")
                                    .font(.title)
                                    .padding(7)
                                    .foregroundColor((cur_screen == .RemindersScreen) ? Color.blue : Color.primary)
                            }
                        }
                    } else {
                        Image(systemName: "list.bullet")
                            .font(.title)
                            .padding(7)
                            .foregroundColor(Color.blue)

                        
                    } //Navigation Link ending
                    
                    Text("Reminders")
                    
                } //VStack ending
                
                
                //HOME BUTTON

                VStack() {
                    if cur_screen != .HomeScreen {
                        NavigationLink(destination: HomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)) {
                            Image(systemName: "house")
                                .font(.title)
                                .foregroundColor((cur_screen == .HomeScreen) ? Color.blue : Color.primary)
                        }
                        .padding(4)
                    } else {
                        Image(systemName: "house")
                            .font(.title)
                            .foregroundColor(Color.blue)
                            .padding(4)
                    }
                    
                    Text("Home")
                    
                } //VStack ending
                
                //BACK BUTTON
                .navigationBarBackButtonHidden(true)
                
                // BACK or DONE BUTTON
                VStack {
                    if keyboard.isKeyboardVisible {
                        // DONE BUTTON
                        Button(action: {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "checkmark")
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                        .padding(1.5)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary, lineWidth: 1))
                        .padding(4)

                        Text("Done")
                    } else {
                        // NORMAL BACK BUTTON
                        Button(action: {
                            if cur_screen != .HomeScreen {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "arrowshape.backward")
                                .font(.title)
                                .foregroundColor(cur_screen == .HomeScreen ? .gray : .primary)
                        }
                        .padding(1.5)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .stroke(cur_screen == .HomeScreen ? .gray : .primary, lineWidth: 1))
                        .padding(4)
                        .disabled(cur_screen == .HomeScreen)

                        Text("Back")
                    }
                }
            } //HStack ending
            .padding(.bottom, 2)
        } //VStack ending
    } //body ending
}
