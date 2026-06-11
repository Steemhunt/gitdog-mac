import Foundation

/// App-wide configuration. Dev points at the local gitdog server; production
/// value is wired at the distribution gate (gitdog-mac#9).
enum AppConfig {
    static let defaultServerURL = URL(string: "http://localhost:3000")!

    /// Server base URL. Override with the GITDOG_SERVER environment variable.
    /// Overrides must be absolute http(s) URLs — anything else (e.g. the
    /// schemeless "localhost:3000", which URL(string:) happily parses with
    /// scheme "localhost" and nil host) is rejected loudly instead of
    /// producing an opaquely broken base URL.
    static var serverURL: URL {
        guard let raw = ProcessInfo.processInfo.environment["GITDOG_SERVER"] else {
            return defaultServerURL
        }
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host() != nil
        else {
            NSLog("GitDog: ignoring invalid GITDOG_SERVER=%@ (need absolute http(s) URL) — using %@",
                  raw, defaultServerURL.absoluteString)
            return defaultServerURL
        }
        return url
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
