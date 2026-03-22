import Foundation

// MARK: - API Response wrappers

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let createdAt: Date
}

struct BankAccount: Codable, Identifiable {
    let id: UUID
    let name: String
    let ibanMasked: String?
    let currency: String
}

struct Transaction: Codable, Identifiable {
    let id: UUID
    let bankAccountId: UUID
    let bookedAt: Date
    let amount: Decimal
    let currency: String
    let merchant: String?
    let normalizedCategory: String?
    let isEssential: Bool
}

struct TreeState: Codable, Identifiable {
    let id: UUID
    let date: Date
    let healthScore: Int
    let leafDensity: Double
    let stressLevel: Double
    let dominantSpendingCategory: String?
    let explanation: String
}

struct SpendingGoal: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let monthlyDiscretionaryBudget: Double
    let monthlySavingsTarget: Double
}

// MARK: - Bank connection

struct Institution: Codable, Identifiable {
    let id: String
    let name: String
    let logoUrl: String
    let countries: [String]
}

struct BankConnection: Codable, Identifiable {
    let id: UUID
    let institutionId: String
    let requisitionId: String
    let status: String
    let authorizationUrl: String?
    let createdAt: Date
    let lastSyncedAt: Date?
}

struct ConnectionStatus: Codable {
    let id: UUID
    let status: String
    let accountsSynced: Int
}

// MARK: - Dashboard

struct Dashboard: Codable {
    // Tree
    let treeState: String
    let healthScore: Int
    let leafDensity: Double
    let stressLevel: Double
    let explanation: String

    // Budget
    let discretionarySpent: Double
    let discretionaryBudget: Double
    let budgetRemaining: Double
    let budgetPercentage: Double
    let daysLeftInMonth: Int

    // Spending
    let topCategories: [CategoryBreakdown]
    let totalSpending: Double
    let totalIncome: Double

    // Actions
    let actions: [ActionRecommendation]

    // Meta
    let savingsProgress: Double
    let trend: String
}

struct CategoryBreakdown: Codable, Identifiable {
    let category: String
    let total: Double
    let count: Int
    let isEssential: Bool

    var id: String { category }

    var displayName: String {
        category.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct ActionRecommendation: Codable, Identifiable {
    let icon: String
    let title: String
    let description: String
    let priority: Int

    var id: String { title }
}

struct SyncResponse: Codable {
    let transactionsSynced: Int
}

struct CSVImportResponse: Codable {
    let transactionsImported: Int
}

// MARK: - Request bodies

struct CreateUserRequest: Codable {
    let email: String
}

struct UpsertGoalRequest: Codable {
    let monthlyDiscretionaryBudget: Double
    let monthlySavingsTarget: Double
}

struct CreateConnectionRequest: Codable {
    let institutionId: String
}
