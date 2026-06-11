import AppKit

/// Drives the menu bar button through the dog's animation states.
///
/// Two kinds of state:
/// - **persistent** (`sleep`, `arrived`) — loop until told otherwise
/// - **transient** (`wag`, `run`) — play for a fixed duration, then fall back
///   to the current persistent state
@MainActor
final class SpriteAnimator {
    private weak var button: NSStatusBarButton?
    private var timer: Timer?
    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var revertWork: DispatchWorkItem?

    /// The persistent state we return to after a transient animation.
    private(set) var baseState: DogState = .sleep

    init(button: NSStatusBarButton) {
        self.button = button
        apply(.sleep)
    }

    /// Switch the persistent state (sleep/arrived). Transient states are
    /// played via `play(_:)`; passing them here treats them as persistent
    /// and is a programmer error in release flows, so they are redirected.
    func setBase(_ state: DogState) {
        switch state {
        case .sleep, .arrived:
            baseState = state
            // don't interrupt a transient celebration; it reverts to the new base
            if revertWork == nil { apply(state) }
        case .wag, .run:
            play(state)
        }
    }

    /// Play a transient celebration, then fall back to the base state.
    /// Persistent states (infinite duration) are redirected to `setBase` —
    /// scheduling an infinite revert would leave `revertWork` set forever and
    /// silently brick every future `setBase`.
    func play(_ state: DogState, duration: TimeInterval? = nil) {
        let seconds = duration ?? Self.defaultDuration(for: state)
        guard seconds.isFinite else {
            setBase(state)
            return
        }
        apply(state)
        revertWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.revertWork = nil
            self.apply(self.baseState)
        }
        revertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // MARK: internals

    private static func defaultDuration(for state: DogState) -> TimeInterval {
        switch state {
        case .wag: 3.0
        case .run: 5.0
        case .sleep, .arrived: .infinity
        }
    }

    private static func frameInterval(for state: DogState) -> TimeInterval {
        switch state {
        case .sleep: 0.9
        case .arrived: 0.6
        case .wag: 0.18
        case .run: 0.12
        }
    }

    private func apply(_ state: DogState) {
        timer?.invalidate()
        frames = Sprites.images(for: state)
        frameIndex = 0
        button?.image = frames[0]
        guard frames.count > 1 else { return }
        let interval = Self.frameInterval(for: state)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.frames.isEmpty else { return }
                self.frameIndex = (self.frameIndex + 1) % self.frames.count
                self.button?.image = self.frames[self.frameIndex]
            }
        }
        // .common keeps the dog animating while menus/popovers track events
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
