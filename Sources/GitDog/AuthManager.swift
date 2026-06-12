import AppKit
import Foundation

/// Owns the sign-in lifecycle:
/// browser handoff → `gitdog://auth/callback` → Keychain → `/api/v1/me`.
///
/// The token is opaque to the app (contract: docs/api-v1.md) — identical
/// handling under the server's dev-mode auth and real GitHub OAuth.
@MainActor
final class AuthManager: ObservableObject {
    enum State: Equatable {
        case signedOut
        case signingIn
        case signedIn(APIClient.Me)
    }

    @Published private(set) var state: State = .signedOut
    @Published var lastError: String?

    static let shared = AuthManager()

    private init() {
        if let token = KeychainTokenStore.load() {
            // restore session; validate in the background
            state = .signingIn
            Task { await validate(token: token) }
        }
    }

    var token: String? { KeychainTokenStore.load() }

    /// Opens the server's auth handoff page in the default browser.
    /// The flow completes when the server redirects to gitdog://auth/callback.
    func beginSignIn(username: String) {
        lastError = nil
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            lastError = "Enter your GitHub username."
            return
        }
        state = .signingIn
        var components = URLComponents(
            url: AppConfig.serverURL.appending(path: "/auth/app"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "username", value: trimmed)]
        NSWorkspace.shared.open(components.url!)
    }

    /// Entry point for the `gitdog://auth/callback` URL (from AppDelegate).
    func handleCallback(_ url: URL) {
        guard url.host() == "auth", url.path() == "/callback" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            state = .signedOut
            lastError = Self.describe(errorCode: error)
            return
        }
        guard let token = items.first(where: { $0.name == "token" })?.value, !token.isEmpty else {
            state = .signedOut
            lastError = "Sign-in failed: no token in callback."
            return
        }
        do {
            try KeychainTokenStore.save(token)
        } catch {
            state = .signedOut
            lastError = "Couldn't store the session: \(error.localizedDescription)"
            return
        }
        state = .signingIn
        Task { await validate(token: token) }
    }

    func signOut() {
        KeychainTokenStore.clear()
        state = .signedOut
        lastError = nil
    }

    /// Confirms the token against /api/v1/me and loads the profile.
    func validate(token: String) async {
        do {
            let me = try await APIClient(token: token).me()
            state = .signedIn(me)
            lastError = nil
        } catch APIClient.APIError.unauthorized {
            KeychainTokenStore.clear()
            state = .signedOut
            lastError = "Session expired — sign in again."
        } catch {
            // network/server hiccup: keep the token, surface the error,
            // and let the user retry instead of dropping the session
            state = .signedOut
            lastError = error.localizedDescription
        }
    }

    private static func describe(errorCode: String) -> String {
        switch errorCode {
        case "invalid_username": "That GitHub username doesn't look valid."
        case "user_not_found": "No GitHub user with that name."
        case "rate_limited": "Too many attempts — try again in a minute."
        default: "Sign-in failed (\(errorCode))."
        }
    }
}
