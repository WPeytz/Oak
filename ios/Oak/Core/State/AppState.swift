import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding: Bool
    @Published var isRestoringSession: Bool = true

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
    }

    func restoreSession() async {
        defer { isRestoringSession = false }
        guard let id = userId else {
            return
        }
        do {
            let user = try await withTimeout(seconds: 5) {
                try await APIClient.shared.getUser(id: id)
            }
            self.currentUser = user
        } catch {
            // User no longer exists or server unreachable — reset
            self.storedUserId = ""
            self.hasCompletedOnboarding = false
        }
    }

    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
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
