import SwiftUI

/// Where the signed-in popover navigates.
enum ReviewerRoute: Equatable {
    case analyzing
    case reveal
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
    let token: String
    @StateObject private var store: ReviewerStore
    @State private var route: ReviewerRoute
    /// Route that opened the breed ladder, so its back button returns there
    /// (escaping onboarding into the inbox was a review finding).
    @State private var ladderBack: ReviewerRoute = .inbox

    init(me: APIClient.Me, token: String, animator: SpriteAnimator?) {
        self.me = me
        self.token = token
        _store = StateObject(wrappedValue: ReviewerStore(token: token, animator: animator))
        // First sign-in on this machine -> the analyze→reveal→price onboarding;
        // returning users go straight to the inbox.
        _route = State(initialValue: OnboardingGate.isDone(userId: me.id) ? .inbox : .analyzing)
    }

    var body: some View {
        Group {
            switch route {
            case .analyzing:
                AnalyzingView(me: me) { route = .reveal }
            case .reveal:
                RevealView(
                    me: me,
                    onSetPrice: { route = .settings },
                    onContinue: {
                        OnboardingGate.markDone(userId: me.id)
                        route = .inbox
                    }
                )
            case .inbox:
                InboxView(store: store, me: me, route: $route)
            case .composer(let req):
                ComposerView(store: store, request: req, route: $route)
            case .treats:
                TreatsView(store: store, me: me, route: $route)
            case .ladder:
                BreedLadderView(me: me, token: token, route: $route, backRoute: ladderBack)
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
