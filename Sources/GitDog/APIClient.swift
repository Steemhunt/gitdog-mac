import Foundation

/// Minimal typed client for the gitdog API v1 contract (docs/api-v1.md in the
/// server repo).
struct APIClient {
    var token: String

    // MARK: response shapes

    struct Me: Decodable, Equatable {
        let id: Int
        let login: String
        let avatarUrl: String?
        let score: Int
        let level: Int
        let breed: String
        let breedLabel: String
        let breedImageUrl: String?
        let priceUsd: String
        let suggestedMaxUsd: String
    }

    struct InboxRequest: Decodable, Equatable, Identifiable {
        let id: Int
        let status: String
        let priceUsd: String
        let expiresAt: Date
        let createdAt: Date
        let repoUrl: String
        let pitch: String
        let from: Sender

        struct Sender: Decodable, Equatable {
            let login: String
            let level: Int
            let breed: String?
        }
    }

    struct Inbox: Decodable { let requests: [InboxRequest] }

    struct RequestState: Decodable, Equatable {
        let id: Int
        let status: String
    }

    struct FeedbackResult: Decodable, Equatable {
        let id: Int
        let status: String
        let copyPasteFlagged: Bool
    }

    struct Treats: Decodable, Equatable {
        let availableUsd: String
        let pendingUsd: String
        let cashoutEligible: Bool
        let cashoutMinUsd: String
        let history: [Entry]

        struct Entry: Decodable, Equatable, Identifiable {
            let type: String
            let amountUsd: String
            let createdAt: Date
            let requestId: Int?
            var id: String { "\(type)-\(createdAt.timeIntervalSince1970)-\(requestId ?? 0)" }
        }
    }

    // MARK: errors

    enum APIError: Error, LocalizedError {
        case unauthorized
        case rateLimited(retryAfter: Int?)
        case server(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .unauthorized: "Session expired — sign in again."
            case .rateLimited(let secs):
                "Slow down a moment\(secs.map { " (\($0)s)" } ?? "")."
            case .server(_, let message): message
            }
        }
    }

    // MARK: endpoints

    func me() async throws -> Me { try await send("GET", "/api/v1/me") }

    func inbox() async throws -> [InboxRequest] {
        let response: Inbox = try await send("GET", "/api/v1/inbox")
        return response.requests
    }

    func startReading(requestId: Int) async throws -> RequestState {
        try await send("POST", "/api/v1/requests/\(requestId)/start")
    }

    func submitFeedback(
        requestId: Int, firstImpression: String, whatWorks: String,
        whatsMissing: String, pawRating: Int
    ) async throws -> FeedbackResult {
        try await send("POST", "/api/v1/requests/\(requestId)/feedback", body: [
            "firstImpression": firstImpression,
            "whatWorks": whatWorks,
            "whatsMissing": whatsMissing,
            "pawRating": pawRating,
        ])
    }

    func treats() async throws -> Treats { try await send("GET", "/api/v1/treats") }

    func heartbeat() async throws { let _: HeartbeatResponse = try await send("POST", "/api/v1/heartbeat") }
    private struct HeartbeatResponse: Decodable { let lastSeenAt: String }

    // MARK: transport

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func send<T: Decodable>(
        _ method: String, _ path: String, body: [String: Any]? = nil
    ) async throws -> T {
        var request = URLRequest(url: AppConfig.serverURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        switch status {
        case 200:
            return try Self.decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 429:
            let retry = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APIError.rateLimited(retryAfter: retry)
        default:
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError.server(status: status, message: message ?? "request failed")
        }
    }
}
