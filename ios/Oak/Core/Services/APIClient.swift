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
        self.baseURL = URL(string: "https://api.oakapp.dk")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Try ISO 8601 datetime first, then plain date
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: string) { return date }
            iso.formatOptions = [.withFullDate, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let date = df.date(from: string) { return date }
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            if let date = df.date(from: string) { return date }
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = df.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
        }

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

    func createUser(email: String, name: String) async throws -> User {
        try await post("api/users/", body: CreateUserRequest(email: email, name: name))
    }

    func loginUser(email: String) async throws -> User {
        try await post("api/users/login", body: CreateUserRequest(email: email, name: ""))
    }

    func getUser(id: UUID) async throws -> User {
        try await get("api/users/\(id)")
    }

    // MARK: - Goals

    func upsertGoal(
        userId: UUID,
        budget: Double,
        savingsTarget: Double,
        netGoal: Double = 0
    ) async throws -> SpendingGoal {
        try await put(
            "api/goals/\(userId)",
            body: UpsertGoalRequest(
                monthlyDiscretionaryBudget: budget,
                monthlySavingsTarget: savingsTarget,
                monthlyNetGoal: netGoal
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

    // MARK: - Savings Goals

    func listSavingsGoals(userId: UUID) async throws -> [SavingsGoal] {
        try await get("api/savings-goals/\(userId)")
    }

    func createSavingsGoal(userId: UUID, name: String, targetAmount: Double) async throws -> SavingsGoal {
        try await post(
            "api/savings-goals/\(userId)",
            body: CreateSavingsGoalRequest(name: name, targetAmount: targetAmount)
        )
    }

    func updateSavingsGoal(userId: UUID, goalId: UUID, name: String? = nil, targetAmount: Double? = nil, currentAmount: Double? = nil) async throws -> SavingsGoal {
        try await put(
            "api/savings-goals/\(userId)/\(goalId)",
            body: UpdateSavingsGoalRequest(name: name, targetAmount: targetAmount, currentAmount: currentAmount)
        )
    }

    
    // MARK: - Slet mål
    func deleteSavingsGoal(userId: UUID, goalId: UUID) async throws {
        try await delete("api/savings-goals/\(userId)/\(goalId)")
    }

    // Du skal også bruge denne hjælpe-funktion i bunden af klassen sammen med get/post/put
    private func delete(_ path: String) async throws {
        var request = URLRequest(url: buildURL(path))
        request.httpMethod = "DELETE"
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }
    
    // MARK: - CSV Import

    func importCSV(userId: UUID, csvData: Data, filename: String) async throws -> CSVImportResponse {
        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/csv\r\n\r\n".data(using: .utf8)!)
        body.append(csvData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: buildURL("api/transactions/\(userId)/import-csv"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    // MARK: - Generic HTTP

    private func buildURL(_ path: String) -> URL {
        // Use string concatenation to avoid appendingPathComponent
        // which escapes query strings and strips trailing slashes
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: base + cleanPath)!
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(from: buildURL(path))
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        var request = URLRequest(url: buildURL(path))
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
        var request = URLRequest(url: buildURL(path))
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

