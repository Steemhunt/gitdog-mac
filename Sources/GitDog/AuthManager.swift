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
    /// Token that reached the Keychain but failed validation on a
    /// network/server error — enables Retry without a new browser handoff.
    @Published private(set) var retryableToken: String?

    private var validateTask: Task<Void, Never>?

    static let shared = AuthManager()

    private init() {
        if let token = KeychainTokenStore.load() {
            // restore session; validate in the background
            state = .signingIn
            startValidation(token: token)
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
    /// SECURITY: any local app can open gitdog:// URLs. We only accept a
    /// callback while a sign-in WE initiated is in flight — otherwise a forged
    /// callback could overwrite the session with an attacker's (valid) token
    /// (login CSRF). A server-echoed state nonce is filed upstream to also
    /// close the in-flight race window.
    func handleCallback(_ url: URL) {
        guard url.host() == "auth", url.path() == "/callback" else { return }
        guard state == .signingIn else {
            NSLog("GitDog: ignoring unsolicited auth callback")
            return
        }
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
        startValidation(token: token)
    }

    func signOut() {
        validateTask?.cancel()
        validateTask = nil
        KeychainTokenStore.clear()
        state = .signedOut
        lastError = nil
        retryableToken = nil
    }

    /// Re-validate a token that previously failed on a network/server error.
    func retryValidation() {
        guard let token = retryableToken else { return }
        retryableToken = nil
        state = .signingIn
        startValidation(token: token)
    }

    private func startValidation(token: String) {
        validateTask?.cancel()
        validateTask = Task { await validate(token: token) }
    }

    /// Confirms the token against /api/v1/me and loads the profile.
    func validate(token: String) async {
        do {
            let me = try await APIClient(token: token).me()
            guard !Task.isCancelled else { return } // signOut/cancel won the race
            state = .signedIn(me)
            lastError = nil
            retryableToken = nil
        } catch APIClient.APIError.unauthorized {
            guard !Task.isCancelled else { return }
            KeychainTokenStore.clear()
            state = .signedOut
            lastError = "Session expired — sign in again."
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            // network/server hiccup: keep the token (Keychain + retryableToken)
            // and surface a real Retry path in the UI
            state = .signedOut
            lastError = error.localizedDescription
            retryableToken = token
        }
    }

    private static func describe(errorCode: String) -> String {
        switch errorCode {
        case "invalid_username": "That GitHub username doesn't look valid."
        case "user_not_found": "No GitHub user with that name."
        case "rate_limited": "Too many attempts — try again in a minute."
        case "auth_failed": "GitHub sign-in didn't complete — try again."
        default: "Sign-in failed (\(errorCode))."
        }
    }
}
