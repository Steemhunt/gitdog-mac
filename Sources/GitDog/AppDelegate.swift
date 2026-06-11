import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController()
        NSLog("GitDog launched — server: \(AppConfig.serverURL.absoluteString)")
        startSpriteDemoIfRequested()
    }

    /// Dev QA: `GITDOG_SPRITE_DEMO=1` cycles the menu bar dog through every
    /// animation state (sleep → arrived → wag → run) on a loop so the sprite
    /// work can be eyeballed in a real light/dark menu bar.
    private func startSpriteDemoIfRequested() {
        guard ProcessInfo.processInfo.environment["GITDOG_SPRITE_DEMO"] == "1",
              let animator = statusController?.animator else { return }
        let schedule: [(TimeInterval, DogState)] = [
            (0, .sleep), (5, .arrived), (10, .wag), (14, .run), (20, .sleep)
        ]
        func loop() {
            for (delay, state) in schedule {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    switch state {
                    case .sleep, .arrived: animator.setBase(state)
                    case .wag, .run: animator.play(state)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { loop() }
        }
        loop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
