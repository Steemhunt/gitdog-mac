import SwiftUI

/// Where the signed-in popover navigates.
enum ReviewerRoute: Equatable {
    case inbox
    case composer(APIClient.InboxRequest)
    case treats
    case settings
    case ladder
}

/// Container for the signed-in experience: owns the ReviewerStore and routes
/// between Inbox / Composer / Treats.
struct SignedInView: View {
    let me: APIClient.Me
    @StateObject private var store: ReviewerStore
    @State private var route: ReviewerRoute
    /// Route that opened the breed ladder, so its back button returns there
    /// (escaping onboarding into the inbox was a review finding).
    @State private var ladderBack: ReviewerRoute = .inbox

    init(me: APIClient.Me, token: String, animator: SpriteAnimator?) {
        self.me = me
        _store = StateObject(wrappedValue: ReviewerStore(token: token, animator: animator))
        // first sign-in on this machine -> price/quiet-hours onboarding first
        _route = State(initialValue: OnboardingGate.isDone(userId: me.id) ? .inbox : .settings)
    }

    var body: some View {
        Group {
            switch route {
            case .inbox:
                InboxView(store: store, me: me, route: $route)
            case .composer(let req):
                ComposerView(store: store, request: req, route: $route)
            case .treats:
                TreatsView(store: store, me: me, route: $route)
            case .ladder:
                BreedLadderView(me: me, route: $route, backRoute: ladderBack)
            case .settings:
                SettingsView(
                    me: me, store: store,
                    isOnboarding: !OnboardingGate.isDone(userId: me.id),
                    onShowLadder: { route = .ladder }
                ) {
                    OnboardingGate.markDone(userId: me.id)
                    route = .inbox
                }
            }
        }
        .onChange(of: route) { old, new in
            if new == .ladder { ladderBack = old }
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
        // popover reopened → refresh immediately
        .onReceive(NotificationCenter.default.publisher(for: .gitdogPopoverDidOpen)) { _ in
            store.refreshNow()
        }
    }
}

extension Notification.Name {
    static let gitdogPopoverDidOpen = Notification.Name("gitdogPopoverDidOpen")
}
