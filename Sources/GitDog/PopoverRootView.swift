import SwiftUI
import ServiceManagement
import AppKit

/// Popover root. Signed-in shows the full reviewer experience (SignedInView,
/// which carries its own chrome); signed-out shows the scaffold chrome around
/// the sign-in form + launch-at-login.
struct PopoverRootView: View {
    let animator: SpriteAnimator?
    @ObservedObject private var auth = AuthManager.shared

    var body: some View {
        Group {
            if case .signedIn(let me) = auth.state, let token = auth.token {
                SignedInView(me: me, token: token, animator: animator)
            } else {
                signedOutChrome
            }
        }
        .frame(width: StatusItemController.popoverSize.width,
               height: StatusItemController.popoverSize.height)
    }

    // The sign-in hero (frame A) carries its own title, so the signed-out screen
    // is the hero itself over a slim launch-at-login/quit footer. (Frame A's
    // bottom-pinned ticker becomes inline above this footer — a menu-bar app
    // still needs a reachable Quit before sign-in.)
    private var signedOutChrome: some View {
        VStack(spacing: 0) {
            SignInView()
            Divider()
            LaunchAtLoginFooter()
        }
    }
}

/// Launch-at-login control. Lives only on the signed-out screen; the signed-in
/// surface has its own footer.
private struct LaunchAtLoginFooter: View {
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?
    /// Suppresses the registration side effect while we sync UI state from the
    /// system (initial read, error revert) — without it, reverting the toggle
    /// after a failed register() re-fires onChange and runs an unintended
    /// unregister(), masking the real error.
    @State private var syncingToggle = false
    @State private var hotkeyEnabled = HotKeyPreference.enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, enabled in
                    guard !syncingToggle else { return }
                    setLaunchAtLogin(enabled)
                }
            // Reachable while signed out: the hotkey is the way back in if the
            // menu bar icon is hidden behind the notch (#29).
            Toggle("Global shortcut (\(GlobalHotKey.displayLabel))", isOn: $hotkeyEnabled)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)
                .onChange(of: hotkeyEnabled) { _, on in
                    HotKeyPreference.enabled = on
                    (NSApp.delegate as? AppDelegate)?.refreshHotKeyRegistration()
                }
            if let error = launchAtLoginError {
                Text(error).font(.system(size: 10)).foregroundStyle(.red)
            }
            HStack {
                Text("v\(AppConfig.appVersion)")
                Spacer()
                Button("Quit GitDog") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .font(.system(size: 11)).padding(.top, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .onAppear(perform: syncFromSystem)
    }

    private func syncFromSystem() {
        syncingToggle = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        syncingToggle = false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLoginError = error.localizedDescription
            syncingToggle = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
            syncingToggle = false
        }
    }
}
