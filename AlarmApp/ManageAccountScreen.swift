//
//  ManageAccountScreen.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 11/9/25.
//

import SwiftUI
import FirebaseAuth

struct ManageAccountScreen: View {
    let firestoreManager: FirestoreManager
    @State private var showDeleteAlert = false
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manage Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Button("Delete Account") {
                showDeleteAlert = true
            }
            .foregroundColor(.white)
            .font(.title2)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.red.opacity(0.8))
            .cornerRadius(12)
            .padding(.horizontal)
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    firestoreManager.deleteCurrentUserAccount { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                // Log out user after deletion
                                do {
                                    try Auth.auth().signOut()
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        window.rootViewController = UIHostingController(rootView: ContentView())
                                    }
                                } catch {
                                    print("Error signing out: \(error.localizedDescription)")
                                }
                            case .failure(let error):
                                print("Failed to delete account: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            } message: {
                Text("This will ") + Text("permanently ").bold() + Text("delete your account and all associated data. Are you sure?")
            }
            
            Spacer()
        }
    }
}
