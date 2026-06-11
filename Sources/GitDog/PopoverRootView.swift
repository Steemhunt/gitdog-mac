import SwiftUI
import ServiceManagement

/// Scaffold root view: brand header, connection target, launch-at-login.
/// The Inbox / composer / Treats screens replace the center section in
/// gitdog-mac#5–#7; sign-in lands with gitdog-mac#4.
struct PopoverRootView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Spacer()
            VStack(spacing: 8) {
                Text("Woof. Nothing here yet —")
                Text("sign-in arrives with the next update.")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            Spacer()
            Divider()
            footer
        }
        .frame(width: 360, height: 420)
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
            // bundled build (scripts/make-app.sh). Surface the real error.
            launchAtLoginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
