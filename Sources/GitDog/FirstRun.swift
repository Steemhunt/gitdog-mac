import SwiftUI

/// One-time first-run flag (app-wide, pre-sign-in) — distinct from the per-user
/// OnboardingGate. Drives the first-launch discovery moment (#30).
enum FirstRunPref {
    private static let key = "gd.firstRunSeen"
    static var seen: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// Shared flag so AppDelegate (which knows it's first launch) can ask the
/// popover content to show its one-time coachmark, and the content can clear it
/// on dismiss / close.
@MainActor
final class CoachmarkState: ObservableObject {
    static let shared = CoachmarkState()
    @Published var showFirstRun = false
    private init() {}
}
