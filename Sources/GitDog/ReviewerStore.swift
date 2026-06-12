import AppKit
import Foundation

/// Observable data layer for the signed-in reviewer: inbox + treats, polled on
/// a cadence and on popover open, driving the menu bar sprite state.
@MainActor
class ReviewerStore: ObservableObject {
    @Published private(set) var inbox: [APIClient.InboxRequest] = []
    @Published private(set) var treats: APIClient.Treats?
    @Published private(set) var loadError: String?

    private let api: APIClient
    private let animator: SpriteAnimator?
    private var pollTimer: Timer?
    private var knownRequestIds: Set<Int> = []
    private var didInitialLoad = false

    /// In-progress feedback per request id, kept on the store so a draft
    /// survives the transient popover closing (e.g. when Open Repo pulls focus)
    /// and reopening. Cleared when the feedback is submitted.
    struct Draft: Equatable {
        var firstImpression = ""
        var whatWorks = ""
        var whatsMissing = ""
        var rating = 0
    }
    private var drafts: [Int: Draft] = [:]

    func draft(for requestId: Int) -> Draft { drafts[requestId] ?? Draft() }
    func saveDraft(_ draft: Draft, for requestId: Int) { drafts[requestId] = draft }
    func clearDraft(for requestId: Int) { drafts[requestId] = nil }

    /// Polling cadence (contract rate limit is 120/min — 60s is well under).
    private static let pollInterval: TimeInterval = 60

    init(token: String, animator: SpriteAnimator?) {
        self.api = APIClient(token: token)
        self.animator = animator
    }

    var client: APIClient { api }

    /// Inject pre-fetched data without polling — used by the UI render harness.
    func seed(inbox: [APIClient.InboxRequest], treats: APIClient.Treats) {
        self.inbox = inbox
        self.treats = treats
        knownRequestIds = Set(inbox.map(\.id))
        didInitialLoad = true
    }

    func start() {
        Task { await refresh() }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Called when the popover opens — immediate freshness without waiting for
    /// the next poll tick.
    func refreshNow() {
        Task { await refresh() }
    }

    /// Play the payout celebration (feedback sent / treats landed).
    func celebrate() {
        animator?.play(.wag)
    }

    /// Cash-out success zoomies.
    func celebrateCashout() {
        animator?.play(.run)
    }

    func refresh() async {
        // Heartbeat is fire-and-forget presence — its failure must NOT drop the
        // inbox/treats the user actually needs (a 429 on the shared token would
        // otherwise blank the UI).
        async let heartbeat: Void = (try? await api.heartbeat()) ?? ()
        do {
            async let inboxCall = api.inbox()
            async let treatsCall = api.treats()
            let (newInbox, newTreats) = try await (inboxCall, treatsCall)
            applyInbox(newInbox)
            treats = newTreats
            loadError = nil
        } catch APIClient.APIError.unauthorized {
            AuthManager.shared.signOut()
        } catch {
            loadError = error.localizedDescription
        }
        await heartbeat
    }

    /// Optimistically drop a request locally after it's answered/started, so the
    /// UI updates before the next poll without inventing server state.
    func removeRequest(id: Int) {
        inbox.removeAll { $0.id == id }
        knownRequestIds.remove(id)
        updateSpriteForInbox()
    }

    func updateStatus(id: Int, status: String) {
        // A request that left the open set (answered/accepted/flagged) drops off
        // the inbox locally before the next poll. Other statuses are coarse and
        // need no local change — avoid a needless @Published publish.
        if ["answered", "accepted", "flagged"].contains(status) {
            inbox.removeAll { $0.id == id }
            updateSpriteForInbox()
        }
    }

    private func applyInbox(_ newInbox: [APIClient.InboxRequest]) {
        let newIds = Set(newInbox.map(\.id))
        let freshArrivals = newIds.subtracting(knownRequestIds)
        inbox = newInbox
        knownRequestIds = newIds

        // a genuinely new request arrived after the first load → celebrate
        if didInitialLoad, !freshArrivals.isEmpty {
            animator?.play(.wag)
            notifyNewRequests(count: freshArrivals.count)
        }
        didInitialLoad = true
        updateSpriteForInbox()
    }

    private func updateSpriteForInbox() {
        animator?.setBase(inbox.isEmpty ? .sleep : .arrived)
    }

    private func notifyNewRequests(count: Int) {
        let note = NSUserNotification()
        note.title = "GitDog"
        note.informativeText = count == 1
            ? "A new repo to review just landed 🦴"
            : "\(count) new repos to review just landed 🦴"
        NSUserNotificationCenter.default.deliver(note)
    }
}
