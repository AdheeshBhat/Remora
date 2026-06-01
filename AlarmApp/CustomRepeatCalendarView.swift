//
//  CustomRepeatCalendarView.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 7/31/25.
//

import SwiftUI

struct CustomRepeatCalendarView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var preloadedReminders: PreloadedReminders
    @Binding var cur_screen: Screen
    @State var title: String
    @State private var selectedDays: Set<Int> = []
    @Binding var repeatSetting: String
    @Binding var customPatterns: Set<String>
    let firestoreManager: FirestoreManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            
            HStack {
                Text("Custom Repeat Pattern")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear") {
                    selectedDays.removeAll()
                }
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red)
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                let columns = Array(repeating: GridItem(.flexible()), count: 7)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(1...31, id: \.self) { day in
                        Button(action: {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        }) {
                            Text("\(day)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(selectedDays.contains(day) ? Color.green : Color.blue.opacity(0.1))
                                .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color.blue.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
                if !selectedDays.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Pattern:")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(selectedDays).sorted(), id: \.self) { day in
                                Text("• Day \(day) of each month")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            
                Button(action: {
                    // Save the custom repeat pattern
                    customPatterns = Set(selectedDays.map { String($0) })
                    if !selectedDays.isEmpty {
                        repeatSetting = "Custom"
                    }
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        
        .onAppear {
            selectedDays = Set(customPatterns.compactMap { Int($0) })
        }
        
        VStack {
            NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager).environmentObject(preloadedReminders)
        }
    }
}
