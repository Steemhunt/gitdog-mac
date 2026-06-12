import SwiftUI

/// Where the signed-in popover navigates.
enum ReviewerRoute: Equatable {
    case inbox
    case composer(APIClient.InboxRequest)
    case treats
}

/// Container for the signed-in experience: owns the ReviewerStore and routes
/// between Inbox / Composer / Treats.
struct SignedInView: View {
    let me: APIClient.Me
    @StateObject private var store: ReviewerStore
    @State private var route: ReviewerRoute = .inbox

    init(me: APIClient.Me, token: String, animator: SpriteAnimator?) {
        self.me = me
        _store = StateObject(wrappedValue: ReviewerStore(token: token, animator: animator))
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
            }
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
