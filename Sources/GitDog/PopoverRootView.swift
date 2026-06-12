import SwiftUI
import ServiceManagement
import AppKit

/// Scaffold root view: brand header, connection target, launch-at-login.
/// The Inbox / composer / Treats screens replace the center section in
/// gitdog-mac#5–#7; sign-in lands with gitdog-mac#4.
struct PopoverRootView: View {
    @ObservedObject private var auth = AuthManager.shared
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?
    /// Suppresses the registration side effect while we sync UI state from
    /// the system (initial read, error revert) — without it, reverting the
    /// toggle after a failed register() re-fires onChange and runs an
    /// unintended unregister(), masking the real error.
    @State private var syncingToggle = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            center
            Divider()
            footer
        }
        .frame(width: StatusItemController.popoverSize.width,
               height: StatusItemController.popoverSize.height)
        .onAppear(perform: syncFromSystem)
    }

    @ViewBuilder
    private var center: some View {
        switch auth.state {
        case .signedOut, .signingIn:
            SignInView()
        case .signedIn(let me):
            VStack(spacing: 10) {
                Spacer()
                if let urlString = me.breedImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().interpolation(.none).scaledToFit()
                    } placeholder: {
                        Text("🐾").font(.system(size: 28))
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Text("@\(me.login)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Text("Lv.\(me.level) \(me.breedLabel) · score \(me.score)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Text("Inbox arrives with the next update.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button("Sign out") { auth.signOut() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("GITDOG")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
            Spacer()
            Text(AppConfig.serverURL.host() ?? "—")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(.system(size: 12))
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, enabled in
                    guard !syncingToggle else { return }
                    setLaunchAtLogin(enabled)
                }
            if let error = launchAtLoginError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            HStack {
                Text("v\(AppConfig.appVersion)")
                Spacer()
                Button("Quit GitDog") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Re-read the real registration state every time the popover opens, so
    /// changes made in System Settings → Login Items are reflected (and the
    /// blocking SMAppService XPC read stays off the app-launch path).
    private func syncFromSystem() {
        syncingToggle = true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        syncingToggle = false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // `swift run` binaries aren't app bundles; SMAppService needs the
            // bundled build (scripts/make-app.sh). Surface the real error and
            // revert the toggle without re-triggering the side effect.
            launchAtLoginError = error.localizedDescription
            syncingToggle = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
            syncingToggle = false
        }
    }
}
