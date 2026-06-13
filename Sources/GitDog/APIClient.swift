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
        /// null for unranked (level-0) users — not yet eligible reviewers
        let breed: String?
        let breedLabel: String?
        let breedImageUrl: String?
        /// null until the reviewer sets a price (first-run onboarding target)
        let priceUsd: String?
        let suggestedMaxUsd: String
        /// Reviewer settings — server truth as of #67 (optional: tolerate an
        /// older deploy that predates the field).
        let maxRequestsPerDay: Int?
        let quietHours: QuietHours?
        /// Score-card stats for the onboarding analysis + reveal (#70).
        /// null until the user has a score snapshot (e.g. brand-new account).
        let stats: ScoreCardStats?
        /// Reviewer eligibility — drives the honest "stray pup" reveal for
        /// unranked users (what's still needed to qualify).
        let eligibility: Eligibility?
    }

    struct Eligibility: Decodable, Equatable {
        let eligible: Bool
        let reasons: [String]
    }

    /// The reveal/analysis numbers behind GET /api/v1/me (#70).
    struct ScoreCardStats: Decodable, Equatable {
        let githubYears: Int
        let publicRepos: Int
        let totalStars: Int
        let lastPushedAt: Date?
        /// 0–100: share of ranked builders scoring below this user.
        let percentile: Int
    }

    /// One ladder rung from GET /api/v1/breeds (#70) — the server is the single
    /// source of truth for thresholds/prices (reflects admin overrides), so the
    /// app no longer mirrors the scoring spec client-side.
    struct BreedLadderEntry: Decodable, Equatable, Identifiable {
        let level: Int
        let breed: String
        let label: String
        let minScore: Int
        let maxPriceUsd: String
        let imageUrl: String
        var id: Int { level }
    }

    /// Unauthenticated social-proof for the sign-in hero (#70). Payouts are
    /// anonymized to breed + level by the server — never a login.
    struct PublicStats: Decodable, Equatable {
        let builders: Int
        let paidThisWeekUsd: String
        let recentPayouts: [RecentPayout]

        struct RecentPayout: Decodable, Equatable, Identifiable {
            let breedLabel: String?
            let level: Int
            let amountUsd: String
            let ago: String
            var id: String { "\(level)-\(ago)-\(amountUsd)" }
        }
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

    /// The breed ladder as server data (#70). The app uses this as the source of
    /// truth for the ladder sheet, falling back to the static spec mirror on error.
    func breeds() async throws -> [BreedLadderEntry] {
        let response: BreedsResponse = try await send("GET", "/api/v1/breeds")
        return response.breeds
    }
    private struct BreedsResponse: Decodable { let breeds: [BreedLadderEntry] }

    /// Public social-proof for the sign-in hero (#70). Unauthenticated — no token
    /// needed, so it loads on the signed-out screen. Static (not an instance
    /// method): the hero shows before any session exists.
    static func publicStats() async throws -> PublicStats {
        let request = URLRequest(url: AppConfig.serverURL.appending(path: "/api/stats/public"))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                  message: "stats unavailable")
        }
        return try decoder.decode(PublicStats.self, from: data)
    }

    struct QuietHours: Codable, Equatable {
        var start: Int      // minute-of-day [0,1440)
        var end: Int
        var timezone: String
    }

    struct Settings: Codable, Equatable {
        var priceUsd: String
        var maxRequestsPerDay: Int
        var quietHours: QuietHours?
    }

    /// Partial update — only provided fields change (contract §settings).
    /// `quietHours: .some(nil)` sends an explicit null to clear them.
    func updateSettings(
        priceUsd: Double? = nil,
        maxRequestsPerDay: Int? = nil,
        quietHours: QuietHours?? = nil
    ) async throws -> Settings {
        var body: [String: Any] = [:]
        if let priceUsd { body["priceUsd"] = priceUsd }
        if let maxRequestsPerDay { body["maxRequestsPerDay"] = maxRequestsPerDay }
        if let quietHours {
            if let qh = quietHours {
                body["quietHours"] = ["start": qh.start, "end": qh.end, "timezone": qh.timezone]
            } else {
                body["quietHours"] = NSNull()
            }
        }
        return try await send("POST", "/api/v1/settings", body: body)
    }

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
