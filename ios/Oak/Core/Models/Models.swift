import Foundation

// MARK: - API Response wrappers

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let name: String
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bankAccountId = try c.decode(UUID.self, forKey: .bankAccountId)
        bookedAt = try c.decode(Date.self, forKey: .bookedAt)
        currency = try c.decode(String.self, forKey: .currency)
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant)
        normalizedCategory = try c.decodeIfPresent(String.self, forKey: .normalizedCategory)
        isEssential = try c.decode(Bool.self, forKey: .isEssential)
        // amount comes as string from the API
        if let str = try? c.decode(String.self, forKey: .amount) {
            amount = Decimal(string: str) ?? 0
        } else {
            amount = try c.decode(Decimal.self, forKey: .amount)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, bankAccountId, bookedAt, amount, currency, merchant, normalizedCategory, isEssential
    }
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
    let monthlyNetGoal: Double?
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

// MARK: - Savings Goals

struct SavingsGoal: Codable, Identifiable {
    let id: UUID
    let name: String
    let targetAmount: Double
    let currentAmount: Double
    let sortOrder: Int
    let progress: Double
}

struct CreateSavingsGoalRequest: Codable {
    let name: String
    let targetAmount: Double
}

struct UpdateSavingsGoalRequest: Codable {
    let name: String?
    let targetAmount: Double?
    let currentAmount: Double?
}

// MARK: - Request bodies

struct CreateUserRequest: Codable {
    let email: String
    let name: String
}

struct UpsertGoalRequest: Codable {
    let monthlyDiscretionaryBudget: Double
    let monthlySavingsTarget: Double
    let monthlyNetGoal: Double
}

struct CreateConnectionRequest: Codable {
    let institutionId: String
}
