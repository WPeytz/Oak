import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, let detail):
            return detail ?? "HTTP error \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

class APIClient {
    static let shared = APIClient()

    let baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.baseURL = URL(string: "http://localhost:8000")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Health

    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        let (_, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    // MARK: - Users

    func createUser(email: String) async throws -> User {
        try await post("api/users", body: CreateUserRequest(email: email))
    }

    func getUser(id: UUID) async throws -> User {
        try await get("api/users/\(id)")
    }

    // MARK: - Goals

    func upsertGoal(
        userId: UUID,
        budget: Double,
        savingsTarget: Double
    ) async throws -> SpendingGoal {
        try await put(
            "api/goals/\(userId)",
            body: UpsertGoalRequest(
                monthlyDiscretionaryBudget: budget,
                monthlySavingsTarget: savingsTarget
            )
        )
    }

    // MARK: - Institutions & Connections

    func listInstitutions(country: String = "DK") async throws -> [Institution] {
        try await get("api/connections/institutions?country=\(country)")
    }

    func createConnection(
        userId: UUID,
        institutionId: String
    ) async throws -> BankConnection {
        try await post(
            "api/connections/\(userId)",
            body: CreateConnectionRequest(
                institutionId: institutionId
            )
        )
    }

    func pollConnectionStatus(
        userId: UUID,
        connectionId: UUID
    ) async throws -> ConnectionStatus {
        try await get("api/connections/\(userId)/\(connectionId)/status")
    }

    // MARK: - Dashboard

    func getDashboard(userId: UUID) async throws -> Dashboard {
        try await get("api/dashboard/\(userId)")
    }

    // MARK: - Transactions

    func syncTransactions(userId: UUID) async throws -> SyncResponse {
        try await post("api/transactions/\(userId)/sync", body: EmptyBody())
    }

    func listTransactions(userId: UUID) async throws -> [Transaction] {
        try await get("api/transactions/\(userId)")
    }

    // MARK: - Generic HTTP

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func put<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = try? JSONDecoder().decode(
                ErrorDetail.self, from: data
            ).detail
            throw APIError.httpError(http.statusCode, detail)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}

private struct ErrorDetail: Decodable {
    let detail: String
}

private struct EmptyBody: Encodable {}
