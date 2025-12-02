//
//  KeyboardHelpers.swift
//  AlarmApp
//
//  Created by Adheesh Bhat on 12/1/25.
//

import Combine
import SwiftUI

final class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { _ in
                self.isKeyboardVisible = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { _ in
                self.isKeyboardVisible = false
            }
            .store(in: &cancellables)
    }
}
