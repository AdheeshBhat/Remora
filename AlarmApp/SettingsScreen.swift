//
//  SettingsScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 8/6/25.
//

import SwiftUI
import FirebaseAuth

class AppearanceModel: ObservableObject {
    @Published var useLightMode: Bool = true
    @Published var defaultToCalendarView: Bool = false
    
    func loadFromFirebase(firestoreManager: FirestoreManager = FirestoreManager()) {
        firestoreManager.loadUserSettings(field: "useLightMode") { value in
            if let savedValue = value as? Bool {
                DispatchQueue.main.async {
                    self.useLightMode = savedValue
                }
            }
        }
        firestoreManager.loadUserSettings(field: "defaultToCalendarView") { value in
            if let savedValue = value as? Bool {
                DispatchQueue.main.async {
                    self.defaultToCalendarView = savedValue
                }
            }
        }
    }
}

struct SettingsScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var appearance: AppearanceModel
    @Binding var cur_screen: Screen
    @State private var isDropdownVisible = false
    @State var selectedSound: String = ""
    @State private var showLogoutAlert = false
    @State private var isCaretaker = false
    @State private var useLightMode: Bool = true
    @State private var username: String = ""
    @State private var tempUseLightMode: Bool = true
    @State private var tempDefaultToCalendarView: Bool = false
    let firestoreManager: FirestoreManager
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack {
                    titleSection
                    Text("General")
                        .font(.title)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom)
                    Toggle("Color Theme (Light Mode):", isOn: $tempUseLightMode)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.bottom)
                    Toggle("Default to Calendar View:", isOn: $tempDefaultToCalendarView)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.bottom)
                    accountHeading
                    if !isCaretaker {
                        usernameSection
                    }
                    notificationRow
                    soundPicker
                    logoutButton
                    
                }
            }
            saveSettingsButton
                .padding(.bottom)
            navBar
        }
        .onAppear {
            cur_screen = .SettingsScreen
            loadSettings()
            self.tempUseLightMode = appearance.useLightMode
            self.tempDefaultToCalendarView = appearance.defaultToCalendarView
            firestoreManager.checkIfCaretaker { result in
                DispatchQueue.main.async {
                    self.isCaretaker = result
                    if !result {
                        firestoreManager.getUsername { fetchedUsername in
                            DispatchQueue.main.async {
                                if let fetchedUsername = fetchedUsername {
                                    self.username = fetchedUsername
                                } else {
                                    self.username = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadSettings() {
        firestoreManager.loadUserSettings(field: "selectedSound") { value in
            DispatchQueue.main.async {
                if let sound = value as? String {
                    selectedSound = sound
                } else {
                    selectedSound = "Chord"
                }
            }
        }
        firestoreManager.loadUserSettings(field: "useLightMode") { value in
            DispatchQueue.main.async {
                if let useLight = value as? Bool {
                    tempUseLightMode = useLight
                }
            }
        }
        firestoreManager.loadUserSettings(field: "defaultToCalendarView") { value in
            DispatchQueue.main.async {
                if let pref = value as? Bool {
                    tempDefaultToCalendarView = pref
                }
            }
        }
    }
}

// MARK: - Subviews
extension SettingsScreen {
    private var titleSection: some View {
        Text("Settings")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top)
            .padding(.bottom)
    }
    
    private var accountHeading: some View {
        Text("Account")
            .font(.title)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom)
    }
    
    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Rounded rectangle container for Username label + value
            HStack {
                Text("Username:")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(username)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom)
            
            // Manage Account button
            NavigationLink(destination: ManageAccountScreen(firestoreManager: firestoreManager)) {
                Text("Manage Account")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.vertical, 12) // reduce vertical padding
                    .padding(.horizontal, 16) // match other rectangles
                    .frame(maxWidth: .infinity, alignment: .leading) // expand full width
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal) // add space from screen edges
            }
        }
        .padding(.bottom)
        
    }
    
    
    private var notificationRow: some View {
        HStack {
            NotificationBellExperience(cur_screen: $cur_screen)
            Text("Notifications")
                .font(.title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.primary)
        }
        .padding(.horizontal)
    }
    
    private var soundPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isDropdownVisible.toggle() }) {
                HStack {
                    Text("Alert Sound:")
                        .foregroundColor(.primary)
                        .font(.headline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(selectedSound)
                        .foregroundColor(.primary)
                        .font(.headline)
                    Image(systemName: isDropdownVisible ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
                .padding(16)
            }
            
            if isDropdownVisible {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(["Chord", "Alert", "Xylophone", "Marimba 1", "Marimba 2"], id: \.self) { sound in
                        Button(action: {
                            selectedSound = sound
                            isDropdownVisible = false
                        }) {
                            Text(sound)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var logoutButton: some View {
        Button(action: { showLogoutAlert = true }) {
            Text("Logout")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color.red)
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .alert("Are you sure?", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                logout()
            }
        } message: {
            Text("You will be signed out of your account.")
        }
    }
    
    
    private var saveSettingsButton: some View {
        Button(action: {
            firestoreManager.saveUserSettings(field: "selectedSound", value: selectedSound) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        firestoreManager.saveUserSettings(field: "useLightMode", value: tempUseLightMode) { error2 in
                            DispatchQueue.main.async {
                                if error2 == nil {
                                    // Success - local state is already updated
                                    appearance.useLightMode = tempUseLightMode
                                    firestoreManager.saveUserSettings(field: "defaultToCalendarView", value: tempDefaultToCalendarView) { err in
                                        DispatchQueue.main.async {
                                            if err == nil {
                                                appearance.defaultToCalendarView = tempDefaultToCalendarView
                                            } else {
                                                print("Failed to save calendar preference: \(err?.localizedDescription ?? "Unknown error")")
                                            }
                                        }
                                    }
                                    presentationMode.wrappedValue.dismiss()
                                } else {
                                    print("Failed to save color mode: \(error2?.localizedDescription ?? "Unknown error")")
                                }
                            }
                        }
                    } else {
                        print("Failed to save settings: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }) {
            Text("Save Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color.green)
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var navBar: some View {
        Group {
            if !isCaretaker {
                NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(rootView: ContentView())
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
