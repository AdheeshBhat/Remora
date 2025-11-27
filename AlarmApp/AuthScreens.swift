//
//  AuthScreens.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 9/14/25.
//

import SwiftUI
import FirebaseAuth

struct LoginScreen: View {
    @Binding var cur_screen: Screen
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    @State private var navigateToHome: Bool = false
    @State private var showRegistration: Bool = false
    @State private var navigateToCaretakerHome: Bool = false
    let firestoreManager = FirestoreManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    VStack() {
                        Image("Remura Logo")
                            .resizable()
                            .scaledToFit()
                        //.frame(width: 500, height: 500)
                        //.font(.system(size: 80))
                        
//                        Text("Reminders made easy for seniors & caregivers")
//                            .font(.title2)
//                            .foregroundColor(.primary)
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal)
                    }
                    //.padding(.bottom, 20)

                    // Login Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .font(.title3)
                                .autocapitalization(.none)
                                .padding(16)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                                )
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .font(.title3)
                                .padding(16)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                                )
                                .textContentType(.password)
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.title3)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            login()
                        }) {
                            Text("Sign In")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(18)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showRegistration.toggle()
                        }) {
                            Text("Create New Account")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemBackground))
            .navigationDestination(isPresented: $navigateToHome) {
                HomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)
            }
            .navigationDestination(isPresented: $navigateToCaretakerHome) {
                CaretakerHomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)
            }
            .navigationDestination(isPresented: $showRegistration) {
                RegistrationScreen(cur_screen: $cur_screen)
            }
        }
    }

    private func login() {
        errorMessage = ""
        
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = ""
                // Navigate to HomeScreen
                cur_screen = .HomeScreen
                firestoreManager.checkIfCaretaker { isCaretaker in
                    if isCaretaker {
                        navigateToCaretakerHome = true
                    } else {
                        navigateToHome = true
                    }
                }
                
            }
        }
    }
}

struct RegistrationScreen: View {
    @Binding var cur_screen: Screen
    @State private var email: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isCaretaker: Bool = false
    @State private var errorMessage: String = ""
    @State private var navigateToHome: Bool = false
    @State private var navigateToCaretakerHome: Bool = false
    @State private var hasConsented: Bool = false
    
    let firestoreManager = FirestoreManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)

                TextField("First Name", text: $firstName)
                    .autocapitalization(.words)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .textContentType(.givenName)
                
                TextField("Last Name", text: $lastName)
                    .autocapitalization(.words)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .textContentType(.familyName)
                
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .textContentType(.password)

                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .textContentType(.password)

                Toggle("Caretaker", isOn: $isCaretaker)
                    .padding()

                PrivacyConsentCheckbox(isChecked: $hasConsented)
                    .padding(.horizontal)
                
                Button(action: {
                    register()
                }) {
                    Text("Register")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationDestination(isPresented: $navigateToHome) {
            HomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)
        }
        .navigationDestination(isPresented: $navigateToCaretakerHome) {
            CaretakerHomeView(cur_screen: $cur_screen, firestoreManager: firestoreManager)
        }
    }

    private func register() {
        errorMessage = ""
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard !username.isEmpty else {
            errorMessage = "Please enter a username."
            return
        }
        guard hasConsented else {
            errorMessage = "You must agree to the Privacy Policy to continue."
            return
        }
        
        //Checks if username is taken
        firestoreManager.getUIDFromUsername(username: username) { existingUID in
            if existingUID != nil {
                errorMessage = "That username is already taken."
            } else {
                Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else if let user = authResult?.user {
                        errorMessage = ""
                        // Save additional user info to Firestore
                        let userData: [String: Any] = [
                            "firstName": firstName,
                            "lastName": lastName,
                            "username": username,
                            "isCaretaker": isCaretaker,
                            "email": email,
                            "uid": user.uid
                        ]
                        firestoreManager.saveUserData(userId: user.uid, data: userData) { error in
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else {
                                // Save username mapping for lookup
                                firestoreManager.saveUsernameMapping(username: username, uid: user.uid) { mappingError in
                                    if let mappingError = mappingError {
                                        print("Error saving username mapping: \(mappingError.localizedDescription)")
                                    } else {
                                        print("Username mapping saved successfully")
                                    }
                                }
                                
                                // Navigate to appropriate HomeScreen
                                cur_screen = .HomeScreen
                                if isCaretaker {
                                    navigateToCaretakerHome = true
                                } else {
                                    navigateToHome = true
                                }
                            }
                        } //saveUserData
                    } //else if ending
                } //createUser ending
            } //else ending
        } //getUIDFromUsername ending
        
    } //private func ending
}


struct PrivacyConsentCheckbox: View {
    @Binding var isChecked: Bool
    let privacyPolicyURL = "https://sites.google.com/view/remura/privacy-policy"

    var body: some View {
        HStack {
            VStack {
                // Combined text with inline link
                Text(.init("I consent to data collection as outlined in the [Privacy Policy](\(privacyPolicyURL))"))
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .onTapGesture {
                        if let url = URL(string: privacyPolicyURL) {
                            UIApplication.shared.open(url)
                        }
                    }
                
            }
            
            VStack {
                Button(action: {
                    isChecked.toggle()
                }) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .foregroundColor(isChecked ? .green : .gray)
                        .font(.title2)
                }
            }
            .padding(.horizontal)
        }
        
    }
}
