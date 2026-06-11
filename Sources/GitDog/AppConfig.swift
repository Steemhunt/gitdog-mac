import Foundation

/// App-wide configuration. Dev points at the local gitdog server; production
/// value is wired at the distribution gate (gitdog-mac#9).
enum AppConfig {
    /// Server base URL. Override with the GITDOG_SERVER environment variable.
    static var serverURL: URL {
        if let raw = ProcessInfo.processInfo.environment["GITDOG_SERVER"],
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://localhost:3000")!
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
