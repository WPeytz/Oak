import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding: Bool

    @AppStorage("userId") private var storedUserId: String = ""

    init() {
        self.hasCompletedOnboarding = !UserDefaults.standard
            .string(forKey: "userId").isNilOrEmpty
        self.currentUser = nil
    }

    var userId: UUID? {
        UUID(uuidString: storedUserId)
    }

    func setUser(_ user: User) {
        self.currentUser = user
        self.storedUserId = user.id.uuidString
        self.hasCompletedOnboarding = true
    }

    func restoreSession() async {
        guard let id = userId else { return }
        do {
            let user = try await APIClient.shared.getUser(id: id)
            self.currentUser = user
        } catch {
            // User no longer exists on server — reset
            self.storedUserId = ""
            self.hasCompletedOnboarding = false
        }
    }

    func signOut() {
        self.currentUser = nil
        self.storedUserId = ""
        self.hasCompletedOnboarding = false
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
