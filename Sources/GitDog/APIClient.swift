import Foundation

/// Minimal typed client for the gitdog API v1 contract (docs/api-v1.md in the
/// server repo). Grows with each screen ticket; auth (#4) only needs `me()`.
struct APIClient {
    var token: String

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

    enum APIError: Error, LocalizedError {
        case unauthorized
        case server(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .unauthorized: "Session expired — sign in again."
            case .server(let status, let message): "\(message) (\(status))"
            }
        }
    }

    func me() async throws -> Me {
        try await get("/api/v1/me")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: AppConfig.serverURL.appending(path: path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return try JSONDecoder().decode(T.self, from: data)
        case 401: throw APIError.unauthorized
        default:
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError.server(status: status, message: message ?? "request failed")
        }
    }
}
