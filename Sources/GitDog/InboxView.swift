import SwiftUI

/// Signed-in home: request list + Treats gauge footer (design screen 1).
struct InboxView: View {
    @ObservedObject var store: ReviewerStore
    let me: APIClient.Me
    @Binding var route: ReviewerRoute

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.cream.opacity(0.1))
            content
            Divider().overlay(Theme.cream.opacity(0.1))
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("GITDOG")
                .font(.custom(Theme.pixelFont, size: 13))
                .foregroundStyle(Theme.orange)
            Spacer()
            if !store.inbox.isEmpty {
                Text("🦴 \(store.inbox.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.orangeSoft)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Theme.orange.opacity(0.15), in: Capsule())
            }
            if let t = store.treats {
                Text(formatUsd(t.availableUsd))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Theme.green.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder
    private var content: some View {
        if store.inbox.isEmpty {
            CaptureScroll {
                VStack(spacing: 10) {
                    if let urlString = me.breedImageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().interpolation(.none).scaledToFit()
                        } placeholder: { Text("🐕").font(.system(size: 30)) }
                        .frame(width: 64, height: 64)
                        .background(Theme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .padding(.top, 12)
                    } else {
                        Text("🐕").font(.system(size: 30)).padding(.top, 12)
                    }
                    Text("No bones yet — they're coming.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.cream)
                    Text("Senders pick by level and activity.\nKeep shipping — your Lv.\(me.level) profile is visible.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.creamDim)
                        .multilineTextAlignment(.center)
                    if let error = store.loadError {
                        Text(error).font(.system(size: 10)).foregroundStyle(Theme.red)
                    }
                    VStack(spacing: 8) {
                        BridgeCard(icon: "📤", title: "Get feedback on YOUR repo",
                                   subtitle: "verified builders from $2 each", arrow: "↗") {
                            WebLinks.openDashboard()
                        }
                        BridgeCard(icon: "📇", title: "Share your Score Card",
                                   subtitle: "claim your launch credit", arrow: "↗") {
                            WebLinks.openScoreCard(login: me.login)
                        }
                        BridgeCard(icon: "⚡", title: "Lower your price",
                                   subtitle: "cheaper builders get picked more", arrow: "→") {
                            route = .settings
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
        } else {
            CaptureScroll {
                VStack(spacing: 10) {
                    ForEach(store.inbox) { req in
                        RequestCard(request: req) { route = .composer(req) }
                    }
                }
                .padding(14)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let t = store.treats {
                Button { route = .treats } label: {
                    HStack(spacing: 10) {
                        Text("Treats").font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.creamDim)
                        TreatsGauge(treats: t)
                        Text("\(formatUsd(t.availableUsd)) / \(formatUsd(t.cashoutMinUsd))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.creamDim)
                    }
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 12) {
                Button("Lv.\(me.level) \(me.breedLabel ?? "UNRANKED")") { route = .ladder }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.orangeSoft)
                Spacer()
                Button("Send a request ↗") { WebLinks.openDashboard() }
                    .buttonStyle(.plain).font(.system(size: 11))
                    .foregroundStyle(Theme.creamDim)
                Button("⚙") { route = .settings }
                    .buttonStyle(.plain).font(.system(size: 12))
                    .foregroundStyle(Theme.creamDim)
                    .help("Settings")
                Button("Sign out") { AuthManager.shared.signOut() }
                    .buttonStyle(.plain).font(.system(size: 11))
                    .foregroundStyle(Theme.creamDim)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

private struct RequestCard: View {
    let request: APIClient.InboxRequest
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(repoName)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text(formatUsd(request.priceUsd))
                    .font(.custom(Theme.pixelFont, size: 11))
                    .foregroundStyle(Theme.green)
            }
            Text(request.pitch)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.creamDim)
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Lv.\(request.from.level) sender")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.orangeSoft)
                Text("·").foregroundStyle(Theme.creamDim)
                Text(expiry).font(.system(size: 11)).foregroundStyle(Theme.creamDim)
                Spacer()
                Button(request.status == "reading" ? "Continue →" : "Check it out →", action: onReview)
                    .buttonStyle(GitDogButton(kind: .accent))
            }
        }
        .padding(13)
        .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.cream.opacity(0.07)))
    }

    private var repoName: String {
        URL(string: request.repoUrl)?.lastPathComponent ?? request.repoUrl
    }
    private var expiry: String {
        let days = Int(request.expiresAt.timeIntervalSinceNow / 86400)
        return days <= 0 ? "expires soon" : "expires in \(days)d"
    }
}

struct TreatsGauge: View {
    let treats: APIClient.Treats
    var body: some View {
        let min = Double(treats.cashoutMinUsd) ?? 50
        let avail = Double(treats.availableUsd) ?? 0
        let frac = min > 0 ? Swift.min(avail / min, 1) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.navyDeep)
                Capsule().fill(LinearGradient(
                    colors: [Theme.green, Theme.greenBright],
                    startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * frac)
            }
        }
        .frame(height: 10)
    }
}

/// Action card used by the empty-inbox bridge (design frame D).
struct BridgeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let arrow: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Text(icon).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                    Text(subtitle).font(.system(size: 10.5))
                        .foregroundStyle(Theme.creamDim)
                }
                Spacer()
                Text(arrow).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.orangeSoft)
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.cream.opacity(0.07)))
        }
        .buttonStyle(.plain)
    }
}
