import SwiftUI

// First-run onboarding flourish (gitdog-mac#19): signin → ANALYZING → REVEAL →
// price settings → inbox. The drama is presentation over data that's ALREADY
// loaded (the `me` payload) — the only delays are stream pacing, never fake
// latency. Honest "stray pup" variant for unranked (level-0) accounts.

/// ANALYZING (design frame B): detective corgi, a climbing score, and terminal
/// lines derived from the real profile, then auto-advances to the reveal.
struct AnalyzingView: View {
    let me: APIClient.Me
    let onDone: () -> Void

    @State private var scoreShown = 0
    @State private var visibleLines = 0

    private var detectiveURL: URL {
        AppConfig.serverURL.appending(path: "/breeds/pose-03-corgi-detective.jpg")
    }

    /// The "✓ done" lines, built from real stats; falls back to a short honest
    /// sequence when there's no score snapshot yet.
    private var lines: [String] {
        var out = ["Found you — @\(me.login)"]
        if let s = me.stats {
            out.append(yearsLine(s.githubYears))
            out.append("\(s.publicRepos) public repos, ★\(s.totalStars) counted")
            if let pushed = s.lastPushedAt {
                // "still shipping" only rings true for a recent push; older ones
                // just state the fact without the cheer.
                let recent = -pushed.timeIntervalSinceNow < 90 * 24 * 3600
                out.append("Pushed code \(relativeAgo(pushed)) ago\(recent ? " — still shipping" : "")")
            }
        } else {
            out.append("No score snapshot yet — sniffing your public work")
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            AsyncImage(url: detectiveURL) { image in
                image.resizable().interpolation(.none).scaledToFit()
            } placeholder: {
                Text("🔍").font(.system(size: 44))
            }
            .frame(width: 116, height: 116)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.orange, lineWidth: 3))
            .padding(.top, 26)

            (Text("SNIFFING… ")
                + Text("\(scoreShown)").foregroundColor(Theme.green)
                + Text("/1000").foregroundColor(Theme.creamDim))
                .font(.custom(Theme.pixelFont, size: 11))
                .padding(.top, 16)

            terminal
                .padding(.horizontal, 22).padding(.top, 14)

            Spacer()
        }
        .task { await runSequence() }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                if idx < visibleLines {
                    HStack(alignment: .top, spacing: 6) {
                        Text("✓").foregroundStyle(Theme.green)
                        Text(line).foregroundStyle(Theme.creamDim)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.vertical, 4)
                    .transition(.opacity)
                }
            }
            if visibleLines >= lines.count {
                Text("Calculating your pedigree▌")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.green)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Theme.navyDeep, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cream.opacity(0.08)))
    }

    @MainActor private func runSequence() async {
        let target = me.score
        if target > 0 {
            let steps = min(target, 28)
            for s in 1...steps {
                try? await Task.sleep(for: .milliseconds(45))
                if Task.isCancelled { return }
                scoreShown = Int((Double(target) * Double(s) / Double(steps)).rounded())
            }
            scoreShown = target
        }
        for i in 0..<lines.count {
            try? await Task.sleep(for: .milliseconds(750))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.3)) { visibleLines = i + 1 }
        }
        try? await Task.sleep(for: .milliseconds(950))
        if !Task.isCancelled { onDone() }
    }

    private func yearsLine(_ years: Int) -> String {
        switch years {
        case 0: "New to GitHub — welcome"
        case 1: "1 year on GitHub"
        default: "\(years) years on GitHub… respect"
        }
    }
}

/// REVEAL (design frame C): the breed verdict — the signature dopamine moment.
/// Ranked users get breed art + level + percentile + earn pill and continue to
/// price settings; unranked users get the honest "stray pup" variant with what's
/// needed to qualify.
struct RevealView: View {
    let me: APIClient.Me
    let onSetPrice: () -> Void
    let onContinue: () -> Void

    private var isRanked: Bool { me.level >= 1 }
    /// Whether the price screen has a real range to offer — mirrors
    /// SettingsView.canPrice so a ranked user with no usable price range isn't
    /// sent to a "pricing locked" screen that contradicts their breed reveal.
    private var canPrice: Bool { (Double(me.suggestedMaxUsd) ?? 0) > 0.5 }

    var body: some View {
        CaptureScroll {
            VStack(spacing: 0) {
                Text(isRanked ? "YOUR PEDIGREE IS READY" : "WE SNIFFED AROUND…")
                    .font(.custom(Theme.pixelFont, size: 9))
                    .foregroundStyle(Theme.creamDim)
                    .tracking(1).padding(.top, 18)

                Text(isRanked ? "YOU'RE A\n\(breedName)!" : "STILL A\nSTRAY PUP")
                    .font(.custom(Theme.pixelFont, size: 15))
                    .foregroundStyle(Theme.orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(6).padding(.top, 10).padding(.horizontal, 8)

                dogArt.padding(.top, 10)

                if isRanked {
                    rankedBody
                } else {
                    strayBody
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var breedName: String { (me.breedLabel ?? me.breed ?? "DOG").uppercased() }

    private var dogArt: some View {
        ZStack {
            if isRanked, let urlStr = me.breedImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().interpolation(.none).scaledToFit()
                } placeholder: {
                    Text("🐾").font(.system(size: 40))
                }
                .frame(width: 116, height: 116)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.orange, lineWidth: 3))
                .overlay(alignment: .topLeading) {
                    Text("LV.\(me.level)")
                        .font(.custom(Theme.pixelFont, size: 9))
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Theme.orange, in: RoundedRectangle(cornerRadius: 7))
                        .offset(x: -8, y: -8)
                }
            } else {
                Text("🐾")
                    .font(.system(size: 48))
                    .frame(width: 116, height: 116)
                    .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cream.opacity(0.2), lineWidth: 2))
            }
        }
    }

    @ViewBuilder private var rankedBody: some View {
        if let topPercent = topPercent {
            Text("top \(topPercent)% of Dogtown")
                .font(.system(size: 11.5)).foregroundStyle(Theme.creamDim).padding(.top, 10)
        }

        scoreBar.padding(.horizontal, 40).padding(.top, 12)

        Text("EARNS UP TO \(formatUsd(me.suggestedMaxUsd)) PER FEEDBACK 🦴")
            .font(.custom(Theme.pixelFont, size: 9))
            .foregroundStyle(Theme.green)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.green, style: StrokeStyle(lineWidth: 2, dash: [4])))
            .padding(.top, 12)

        VStack(spacing: 8) {
            if canPrice {
                Button("Set my price & start earning →", action: onSetPrice)
                    .buttonStyle(GitDogButton(kind: .accent, fullWidth: true))
            } else {
                Button("Start earning →", action: onContinue)
                    .buttonStyle(GitDogButton(kind: .accent, fullWidth: true))
            }
            Button("Share my Score Card ↗") { WebLinks.openScoreCard(login: me.login) }
                .buttonStyle(GitDogButton(kind: .ghost, fullWidth: true))
        }
        .padding(.horizontal, 24).padding(.top, 14)

        Text("share → claim your $10 launch credit")
            .font(.system(size: 10.5)).foregroundStyle(Theme.orangeSoft).padding(.top, 8)
    }

    @ViewBuilder private var strayBody: some View {
        Text("Not enough public history to rank you — yet. Keep shipping and check back.")
            .font(.system(size: 11.5)).foregroundStyle(Theme.creamDim)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28).padding(.top, 12)

        if let reasons = me.eligibility?.reasons, !reasons.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(reasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(Theme.orangeSoft)
                        Text(reason).foregroundStyle(Theme.creamDim)
                    }
                    .font(.system(size: 11))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13).padding(.horizontal, 4)
            .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24).padding(.top, 12)
        }

        VStack(spacing: 8) {
            Button("Got it →", action: onContinue)
                .buttonStyle(GitDogButton(kind: .accent, fullWidth: true))
            Button("Share my Score Card ↗") { WebLinks.openScoreCard(login: me.login) }
                .buttonStyle(GitDogButton(kind: .ghost, fullWidth: true))
        }
        .padding(.horizontal, 24).padding(.top, 14)
    }

    /// "top N%" from the percentile (share scoring below). Hidden when there are
    /// no ranked peers yet (percentile 0) — "top 100%" would read as a bug.
    private var topPercent: Int? {
        guard let p = me.stats?.percentile, p > 0 else { return nil }
        return max(1, 100 - p)
    }

    private var scoreBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("score").foregroundStyle(Theme.creamDim)
                Spacer()
                Text("\(me.score) / 1000").foregroundStyle(Theme.creamDim)
            }
            .font(.system(size: 11, design: .monospaced))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7).fill(Theme.navyDeep)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.cream.opacity(0.3), lineWidth: 1.5))
                    RoundedRectangle(cornerRadius: 7).fill(Theme.orange)
                        .frame(width: geo.size.width * fillFraction)
                }
            }
            .frame(height: 12)
        }
    }

    private var fillFraction: CGFloat {
        min(max(CGFloat(me.score) / 1000, 0), 1)
    }
}

/// Short relative age like "3d", "5h", "just now" for the analysis stream.
func relativeAgo(_ date: Date) -> String {
    let secs = max(0, -date.timeIntervalSinceNow)
    if secs < 60 { return "moments" }
    let mins = Int(secs / 60)
    if mins < 60 { return "\(mins)m" }
    let hours = mins / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 7 { return "\(days)d" }
    return "\(days / 7)w"
}
