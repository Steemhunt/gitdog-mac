import SwiftUI
import ServiceManagement

/// Onboarding (first sign-in) and Settings (from the Inbox footer) share this
/// screen — design screen 4: price slider capped at the level's suggested max,
/// daily cap, quiet hours, launch-at-login.
///
/// Server truth gap: /api/v1/me doesn't return maxRequestsPerDay/quietHours yet
/// (filed Steemhunt/gitdog#67), so last-saved values persist locally per user
/// and the price initializes from `me.priceUsd` (which IS server truth).
struct SettingsView: View {
    let me: APIClient.Me
    @ObservedObject var store: ReviewerStore
    let isOnboarding: Bool
    let onDone: () -> Void

    @State private var price: Double = 0
    @State private var maxPerDay: Int = 3
    @State private var quietEnabled = false
    @State private var quietStart = 23 * 60   // 11pm
    @State private var quietEnd = 8 * 60      // 8am
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var syncingLogin = false
    @State private var saving = false
    @State private var error: String?
    @State private var loaded = false

    private var suggestedMax: Double { Double(me.suggestedMaxUsd) ?? 20 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.cream.opacity(0.1))
            CaptureScroll {
                VStack(alignment: .leading, spacing: 18) {
                    profile
                    priceSection
                    stepperRow
                    quietSection
                    loginToggle
                    if let error {
                        Text(error).font(.system(size: 11)).foregroundStyle(Theme.red)
                    }
                    Button(saving ? "Saving…" : (isOnboarding ? "Start receiving requests 🦴" : "Save")) {
                        Task { await save() }
                    }
                    .buttonStyle(GitDogButton(kind: .accent, fullWidth: true))
                    .disabled(saving)
                }
                .padding(16)
            }
        }
        .onAppear(perform: loadOnce)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if !isOnboarding {
                Button { onDone() } label: { Text("←").font(.system(size: 15)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.cream)
            }
            Text(isOnboarding ? "SET YOUR PRICE" : "SETTINGS")
                .font(.custom(Theme.pixelFont, size: 11))
                .foregroundStyle(Theme.orange)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var profile: some View {
        HStack(spacing: 12) {
            if let urlString = me.breedImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().interpolation(.none).scaledToFit()
                } placeholder: {
                    Text("🐾").font(.system(size: 22))
                }
                .frame(width: 56, height: 56)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.orange, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("@\(me.login)").font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Theme.cream)
                Text("Lv.\(me.level) \(me.breedLabel) · score \(me.score)")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.orangeSoft)
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Per feedback you'll earn")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.creamDim)
                Spacer()
                Text(String(format: "$%.2f", price))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.green)
            }
            Slider(value: $price, in: 0.5...suggestedMax, step: 0.5)
                .tint(Theme.orange)
            HStack {
                Text("lower price → more requests")
                Spacer()
                Text("suggested max \(formatUsd(me.suggestedMaxUsd))")
            }
            .font(.system(size: 10.5)).foregroundStyle(Theme.creamDim)
        }
    }

    private var stepperRow: some View {
        HStack {
            Text("Max requests per day")
                .font(.system(size: 13)).foregroundStyle(Theme.cream)
            Spacer()
            Stepper("\(maxPerDay)", value: $maxPerDay, in: 0...20)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.cream)
                .fixedSize()
        }
    }

    private var quietSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Quiet hours", isOn: $quietEnabled)
                .font(.system(size: 13)).foregroundStyle(Theme.cream)
                .toggleStyle(.switch).tint(Theme.orange)
            if quietEnabled {
                HStack(spacing: 10) {
                    minutePicker("From", selection: $quietStart)
                    minutePicker("Until", selection: $quietEnd)
                    Spacer()
                    Text(TimeZone.current.identifier)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.creamDim)
                }
            }
        }
    }

    private func minutePicker(_ label: String, selection: Binding<Int>) -> some View {
        Picker(label, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour * 60)
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 12))
        .frame(width: 110)
    }

    private var loginToggle: some View {
        Toggle("Launch at login", isOn: $launchAtLogin)
            .font(.system(size: 13)).foregroundStyle(Theme.cream)
            .toggleStyle(.switch).tint(Theme.orange)
            .onChange(of: launchAtLogin) { _, enabled in
                guard !syncingLogin else { return }
                do {
                    if enabled { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    self.error = error.localizedDescription
                    syncingLogin = true
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                    syncingLogin = false
                }
            }
    }

    // MARK: load/save

    private func loadOnce() {
        guard !loaded else { return }
        loaded = true
        price = min(Double(me.priceUsd) ?? suggestedMax * 0.7, suggestedMax)
        let saved = LocalSettings.load(userId: me.id)
        maxPerDay = saved?.maxRequestsPerDay ?? 3
        if let qh = saved?.quietHours {
            quietEnabled = true
            quietStart = qh.start
            quietEnd = qh.end
        }
    }

    private func save() async {
        saving = true
        error = nil
        let quietHours: APIClient.QuietHours? = quietEnabled
            ? .init(start: quietStart, end: quietEnd, timezone: TimeZone.current.identifier)
            : nil
        do {
            let settings = try await store.client.updateSettings(
                priceUsd: price,
                maxRequestsPerDay: maxPerDay,
                quietHours: .some(quietHours)
            )
            LocalSettings.save(settings, userId: me.id)
            onDone()
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}

/// Last-saved reviewer settings, persisted per user id so the screen can show
/// current values until the server exposes them in /me (gitdog#67).
enum LocalSettings {
    private static func key(_ userId: Int) -> String { "gd.settings.\(userId)" }

    static func save(_ settings: APIClient.Settings, userId: Int) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key(userId))
        }
    }

    static func load(userId: Int) -> APIClient.Settings? {
        guard let data = UserDefaults.standard.data(forKey: key(userId)) else { return nil }
        return try? JSONDecoder().decode(APIClient.Settings.self, from: data)
    }
}

/// First-run gate: has this user completed onboarding on this machine?
enum OnboardingGate {
    private static func key(_ userId: Int) -> String { "gd.onboarded.\(userId)" }
    static func isDone(userId: Int) -> Bool { UserDefaults.standard.bool(forKey: key(userId)) }
    static func markDone(userId: Int) { UserDefaults.standard.set(true, forKey: key(userId)) }
}
