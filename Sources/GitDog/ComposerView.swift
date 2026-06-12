import SwiftUI

/// Feedback composer (design screen 2): repo card, 3 prompts, paw rating,
/// 280-char gate, submit. Drafts persist per request id while the popover lives.
struct ComposerView: View {
    @ObservedObject var store: ReviewerStore
    let request: APIClient.InboxRequest
    @Binding var route: ReviewerRoute

    @State private var firstImpression = ""
    @State private var whatWorks = ""
    @State private var whatsMissing = ""
    @State private var rating = 0
    @State private var submitting = false
    @State private var error: String?
    @State private var didStart = false

    private static let minChars = 280

    private var totalChars: Int {
        firstImpression.count + whatWorks.count + whatsMissing.count
    }
    private var canSubmit: Bool {
        totalChars >= Self.minChars && rating >= 1 && !submitting
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(Theme.cream.opacity(0.1))
            CaptureScroll {
                VStack(alignment: .leading, spacing: 14) {
                    repoCard
                    prompt("First impression — what did you think this was?",
                           text: $firstImpression, placeholder: "Before opening it, I expected…")
                    prompt("What works?", text: $whatWorks, placeholder: "The part that clicked for me…")
                    prompt("What's confusing or missing?", text: $whatsMissing,
                           placeholder: "I got lost when…")
                    ratingRow
                    if let error {
                        Text(error).font(.system(size: 11)).foregroundStyle(Theme.red)
                    }
                    Button(submitting ? "Sending…" : "Send Feedback · earn \(formatUsd(request.priceUsd))") {
                        Task { await submit() }
                    }
                    .buttonStyle(GitDogButton(kind: .money, fullWidth: true))
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.45)
                }
                .padding(16)
            }
        }
        .task { await startReadingOnce() }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { route = .inbox } label: { Text("←").font(.system(size: 15)) }
                .buttonStyle(.plain).foregroundStyle(Theme.cream)
            Text(repoName.uppercased())
                .font(.custom(Theme.pixelFont, size: 11))
                .foregroundStyle(Theme.orange)
            Spacer()
            Text(formatUsd(request.priceUsd))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.green)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Theme.green.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var repoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(request.repoUrl.replacingOccurrences(of: "https://github.com/", with: ""))
                    .font(.system(size: 13.5, design: .monospaced))
                    .foregroundStyle(Theme.cream)
                Text(request.pitch).font(.system(size: 11))
                    .foregroundStyle(Theme.creamDim).lineLimit(2)
            }
            Spacer()
            Button("Open Repo ↗") { openRepo() }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.orangeSoft)
        }
        .padding(12)
        .background(Theme.navyCard, in: RoundedRectangle(cornerRadius: 13))
    }

    private func prompt(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.cream)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(.system(size: 12.5))
                        .foregroundStyle(Theme.creamDim.opacity(0.6))
                        .padding(.horizontal, 5).padding(.vertical, 8)
                }
                TextEditor(text: text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.cream)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 54)
                    .padding(4)
            }
            .background(Theme.navyDeep, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cream.opacity(0.12)))
        }
    }

    private var ratingRow: some View {
        HStack(spacing: 8) {
            Text("Rating").font(.system(size: 12.5)).foregroundStyle(Theme.creamDim)
            ForEach(1...5, id: \.self) { i in
                Text("🐾")
                    .font(.system(size: 17))
                    .opacity(i <= rating ? 1 : 0.25)
                    .onTapGesture { rating = i }
            }
            Spacer()
            Text("\(totalChars) / \(Self.minChars)")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(totalChars >= Self.minChars ? Theme.green : Theme.creamDim)
        }
    }

    private var repoName: String {
        URL(string: request.repoUrl)?.lastPathComponent ?? request.repoUrl
    }

    private func openRepo() {
        guard let url = URL(string: request.repoUrl),
              url.scheme == "https", url.host()?.hasSuffix("github.com") == true
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func startReadingOnce() async {
        guard !didStart, request.status == "pending" else { return }
        didStart = true
        _ = try? await store.client.startReading(requestId: request.id)
    }

    private func submit() async {
        submitting = true
        error = nil
        do {
            let result = try await store.client.submitFeedback(
                requestId: request.id,
                firstImpression: firstImpression, whatWorks: whatWorks,
                whatsMissing: whatsMissing, pawRating: rating)
            store.updateStatus(id: request.id, status: result.status)
            store.celebrate()
            await store.refresh()
            route = .inbox
        } catch let APIClient.APIError.server(_, message) {
            error = message
        } catch {
            self.error = error.localizedDescription
        }
        submitting = false
    }
}
