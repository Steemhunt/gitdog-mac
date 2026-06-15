import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController()
        NSLog("GitDog launched — server: \(AppConfig.serverURL.absoluteString)")
        refreshHotKeyRegistration()
        maybeRunFirstRunMoment()
        startSpriteDemoIfRequested()
    }

    /// First launch only (#30): auto-open the popover and flag the one-time
    /// coachmark so a new user immediately sees the app and learns where it
    /// lives + how to reopen it. Deferred one run-loop tick so the just-created
    /// status item has laid out before openPopover()'s occlusion check runs.
    private func maybeRunFirstRunMoment() {
        guard !FirstRunPref.seen else { return }
        FirstRunPref.seen = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            CoachmarkState.shared.showFirstRun = true
            self.statusController?.openPopover()
        }
    }

    /// Dock/Spotlight re-launch of the running menu-bar app (no windows) →
    /// surface the popover. Returning true tells AppKit we handled the reopen.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        statusController?.openPopover()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.unregister()
    }

    /// Register/unregister the global hotkey to match the (app-wide) preference.
    /// Called at launch and whenever the Settings toggle flips at runtime.
    func refreshHotKeyRegistration() {
        if HotKeyPreference.enabled {
            if hotKey == nil {
                hotKey = GlobalHotKey { [weak self] in self?.statusController?.togglePopover() }
            }
            hotKey?.register()
        } else {
            hotKey?.unregister()
        }
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

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "gitdog" {
            AuthManager.shared.handleCallback(url)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
