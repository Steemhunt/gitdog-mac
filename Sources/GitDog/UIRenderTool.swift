import AppKit
import SwiftUI

/// Dev harness: `GITDOG_RENDER_UI=/dir GITDOG_RENDER_TOKEN=<jwt> GitDog`
/// signs in with the token, fetches REAL inbox/treats/me from the server, and
/// renders each signed-in screen to PNG, then exits. Lets the reviewer screens
/// be eyeballed without driving the menu bar. Env-gated; unreachable normally.
@MainActor
enum UIRenderTool {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["GITDOG_RENDER_UI"],
              let token = ProcessInfo.processInfo.environment["GITDOG_RENDER_TOKEN"]
        else { return }

        UIRenderMode.active = true  // swap ScrollView→VStack so offscreen capture sees content

        // The render work is async (it fetches real data), so it must live in a
        // Task. But this runs in main() BEFORE NSApplication.run(), and a bare
        // Task scheduled here never drains — its main-actor executor isn't
        // serviced until the app's run loop spins. So we pump RunLoop.main here
        // until the work signals done, then exit (mirroring the synchronous
        // sprite harness, which never reaches app.run() either).
        var done = false
        Task { @MainActor in
            await renderAll(dir: dir, token: token)
            done = true
        }
        while !done {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        exit(0)
    }

    private static func renderAll(dir: String, token: String) async {
        let base = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let api = APIClient(token: token)
        do {
            let me = try await api.me()
            let inbox = try await api.inbox()
            let treats = try await api.treats()

            let store = PreviewStore(token: token, inbox: inbox, treats: treats)
            render(InboxView(store: store, me: me, route: .constant(.inbox)),
                   to: base.appendingPathComponent("inbox.png"))
            render(TreatsView(store: store, me: me, route: .constant(.treats)),
                   to: base.appendingPathComponent("treats.png"))
            if let first = inbox.first {
                render(ComposerView(store: store, request: first, route: .constant(.composer(first))),
                       to: base.appendingPathComponent("composer.png"))
            }
            render(SettingsView(me: me, store: store, isOnboarding: true, onDone: {}),
                   to: base.appendingPathComponent("onboarding.png"))
            let emptyStore = PreviewStore(token: token, inbox: [], treats: treats)
            render(InboxView(store: emptyStore, me: me, route: .constant(.inbox)),
                   to: base.appendingPathComponent("inbox-empty.png"))
            render(BreedLadderView(me: me, token: token, route: .constant(.ladder)),
                   to: base.appendingPathComponent("ladder.png"))
            // SignInView is intentionally not rendered here: its social proof and
            // payout ticker are .task-driven, which ImageRenderer's synchronous
            // snapshot can't run, so the capture would only show the static
            // skeleton. Verify the hero in the live menu bar instead.
            render(RevealView(me: me, onSetPrice: {}, onContinue: {}),
                   to: base.appendingPathComponent("reveal.png"))
            print("UI rendered to \(base.path)")
        } catch {
            print("UI render failed: \(error)")
        }
    }

    private static func render(_ view: some View, to url: URL) {
        let wrapped = view
            .frame(width: StatusItemController.popoverSize.width,
                   height: StatusItemController.popoverSize.height)
            .background(Theme.navy)
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}

/// A ReviewerStore preloaded with already-fetched data (no polling) — for the
/// render harness only.
@MainActor
private final class PreviewStore: ReviewerStore {
    init(token: String, inbox: [APIClient.InboxRequest], treats: APIClient.Treats) {
        super.init(token: token, animator: nil)
        seed(inbox: inbox, treats: treats)
    }
}

/// Dev-only flag: when the UI render harness is active, the screen views lay
/// their scrollable section out in a plain VStack instead of a ScrollView,
/// because ImageRenderer cannot capture ScrollView content. No effect on the
/// shipping app (only UIRenderTool sets it).
@MainActor
enum UIRenderMode {
    static var active = false
}

/// Wraps scrollable content: a real ScrollView in the app, a plain VStack
/// under the render harness.
struct CaptureScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        if UIRenderMode.active {
            content
        } else {
            ScrollView { content }
        }
    }
}
