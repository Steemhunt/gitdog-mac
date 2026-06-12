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
        do {
            async let inboxCall = api.inbox()
            async let treatsCall = api.treats()
            async let heartbeat: Void = api.heartbeat()
            let (newInbox, newTreats, _) = try await (inboxCall, treatsCall, heartbeat)
            applyInbox(newInbox)
            treats = newTreats
            loadError = nil
        } catch APIClient.APIError.unauthorized {
            AuthManager.shared.signOut()
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Optimistically drop a request locally after it's answered/started, so the
    /// UI updates before the next poll without inventing server state.
    func removeRequest(id: Int) {
        inbox.removeAll { $0.id == id }
        knownRequestIds.remove(id)
        updateSpriteForInbox()
    }

    func updateStatus(id: Int, status: String) {
        if let idx = inbox.firstIndex(where: { $0.id == id }) {
            var updated = inbox
            // InboxRequest is immutable; rebuild by removing if it left the
            // open set, otherwise leave as-is (status shown is coarse).
            if status == "answered" || status == "accepted" || status == "flagged" {
                updated.remove(at: idx)
            }
            inbox = updated
        }
        updateSpriteForInbox()
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
