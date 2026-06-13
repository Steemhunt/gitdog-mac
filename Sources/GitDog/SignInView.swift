import SwiftUI

/// Signed-out hero (design frame A, gitdog-mac#18): product story + live social
/// proof before the GitHub handoff. Proof and the payout ticker come from the
/// unauthenticated public-stats endpoint and degrade gracefully — when the
/// server is unreachable the ticks stay (they're static truth) and the
/// proof/ticker simply hide. Copy sells *first impressions*, never "code review".
struct SignInView: View {
    @ObservedObject var auth = AuthManager.shared
    @State private var username = ""
    @State private var stats: APIClient.PublicStats?
    @State private var tickerIndex = 0

    /// Corgi hero art, served by the API (never bundled) like every breed image.
    private var heroArtURL: URL { AppConfig.serverURL.appending(path: "/breeds/breed-03-corgi.jpg") }

    var body: some View {
        VStack(spacing: 0) {
            heroDog
            headline
            ticks
            if let proof = proofText {
                proofPill(proof)
            }
            loginBox
            if let error = auth.lastError {
                Text(error)
                    .font(.system(size: 11)).foregroundStyle(Theme.red)
                    .multilineTextAlignment(.center).padding(.horizontal, 16).padding(.top, 6)
            }
            Spacer(minLength: 8)
            payoutTicker
        }
        .padding(.top, 14)
        .task { stats = try? await APIClient.publicStats() }
    }

    private var heroDog: some View {
        AsyncImage(url: heroArtURL) { image in
            image.resizable().interpolation(.none).scaledToFit()
        } placeholder: {
            Text("🐕").font(.system(size: 40))
        }
        .frame(width: 92, height: 92)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.orange, lineWidth: 3))
    }

    private var headline: some View {
        (Text("A DOG THAT\n")
            + Text("PAYS YOU").foregroundColor(Theme.orange)
            + Text(" FOR\nFIRST IMPRESSIONS"))
            .font(.custom(Theme.pixelFont, size: 11))
            .multilineTextAlignment(.center)
            .lineSpacing(7)
            .foregroundStyle(Theme.cream)
            .padding(.horizontal, 14).padding(.top, 14)
    }

    private var ticks: some View {
        VStack(alignment: .leading, spacing: 5) {
            tick("Check out a project in 5 minutes, earn $2–20")
            tick("Real USDC — cash out from $50")
            tick("GitHub-verified builders only")
        }
        .padding(.horizontal, 34).padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tick(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("✓").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.green)
            Text(text).font(.system(size: 11.5)).foregroundStyle(Theme.creamDim)
        }
    }

    /// Social-proof pill text. With payouts this week it leads with the money
    /// ("127 builders earned $1,284 this week"); before the first payout it falls
    /// back to the ranked-builder count rather than show a deflating "$0". Hidden
    /// entirely until at least one builder is ranked.
    private var proofText: String? {
        guard let s = stats, s.builders > 0 else { return nil }
        if (Double(s.paidThisWeekUsd) ?? 0) > 0 {
            return "\(s.builders) builders earned \(formatUsd(s.paidThisWeekUsd)) this week"
        }
        return "\(s.builders) ranked builders on GitDog"
    }

    private func proofPill(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.green).frame(width: 7, height: 7)
            Text(text).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.green)
        }
        .padding(.vertical, 5).padding(.horizontal, 13)
        .background(Theme.green.opacity(0.12), in: Capsule())
        .padding(.top, 11)
    }

    private var loginBox: some View {
        VStack(spacing: 8) {
            TextField("GitHub username", text: $username)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(Theme.navyDeep, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cream.opacity(0.14)))
                .foregroundStyle(Theme.cream)
                .onSubmit(submit)
            Button(action: submit) {
                Text(auth.state == .signingIn ? "Waiting for the browser…" : "Show me my score →")
            }
            .buttonStyle(GitDogButton(kind: .accent, fullWidth: true))
            .disabled(auth.state == .signingIn)

            if auth.retryableToken != nil {
                Button("Retry") { auth.retryValidation() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.orangeSoft)
            }
            if auth.state == .signingIn {
                Button("Cancel") { auth.signOut() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.creamDim)
            }
        }
        .padding(.horizontal, 24).padding(.top, 14)
    }

    /// Rotating anonymized payout line (no login — privacy by design on the
    /// public endpoint). Hidden until at least one payout exists.
    @ViewBuilder private var payoutTicker: some View {
        if let payouts = stats?.recentPayouts, !payouts.isEmpty {
            let p = payouts[tickerIndex % payouts.count]
            Text(tickerLine(p))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.creamDim)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .transition(.opacity)
                .id(tickerIndex)
                .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
                    withAnimation(.easeInOut(duration: 0.4)) { tickerIndex += 1 }
                }
        }
    }

    private func tickerLine(_ p: APIClient.PublicStats.RecentPayout) -> AttributedString {
        let breed = p.breedLabel ?? "builder"
        let amount = "+" + formatUsd(magnitude(p.amountUsd))
        var s = AttributedString("A \(breed) just earned ")
        var amt = AttributedString(amount)
        amt.foregroundColor = Theme.green
        let tail = AttributedString(" · \(p.ago) ago")
        s.append(amt); s.append(tail)
        return s
    }

    /// Earnings read as positive in the ticker regardless of the ledger's sign
    /// convention for cashouts.
    private func magnitude(_ raw: String) -> String { String(abs(Double(raw) ?? 0)) }

    private func submit() {
        auth.beginSignIn(username: username)
    }
}
