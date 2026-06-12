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
            VStack(spacing: 10) {
                Spacer()
                Text("🐕")
                    .font(.system(size: 34))
                Text("No requests right now.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.cream)
                Text("Keep building — bones roll in while you work.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.creamDim)
                if let error = store.loadError {
                    Text(error).font(.system(size: 10)).foregroundStyle(Theme.red)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
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
            HStack(spacing: 14) {
                Text("Lv.\(me.level) \(me.breedLabel)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.orangeSoft)
                Spacer()
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
                Button(request.status == "reading" ? "Continue →" : "Review →", action: onReview)
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
