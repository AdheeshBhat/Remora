//
//  SettingsScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 8/6/25.
//

import SwiftUI
import FirebaseAuth

struct SettingsScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var cur_screen: Screen
    @State private var isDropdownVisible = false
    @State var selectedSound: String = ""
    @State private var showLogoutAlert = false
    let firestoreManager: FirestoreManager
    
    var body: some View {
        VStack {
            titleSection
            accountHeading
            notificationRow
            soundPicker
            logoutButton
            Spacer()
            saveSettingsButton
            navBar
        }
        .onAppear {
            cur_screen = .SettingsScreen
            loadSettings()
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
    
    private var notificationRow: some View {
        HStack {
            NotificationBellExperience(cur_screen: $cur_screen)
            Text("Notifications")
                .font(.title3)
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
                    ForEach(["Chord", "Alert"], id: \.self) { sound in
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
                        // Success - local state is already updated
                        presentationMode.wrappedValue.dismiss()
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
        NavigationBarExperience(cur_screen: $cur_screen, firestoreManager: firestoreManager)
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
