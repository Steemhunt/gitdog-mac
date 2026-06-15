import AppKit
import SwiftUI

/// Owns the NSStatusItem (menu bar dog) and the NSPopover that anchors to it.
/// The popover can also be opened from the global hotkey (#29) and on app
/// reopen; when the menu bar icon is occluded (behind the notch / overflowed)
/// it falls back to a floating anchor at the top-right so the popover is always
/// reachable on-screen — keeping the app menu-bar-only (no Dock icon).
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    /// Single source of truth for the popover size (PopoverRootView matches it).
    static let popoverSize = NSSize(width: 360, height: 420)

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private(set) var animator: SpriteAnimator?
    /// Set when the transient popover closes; lets the BUTTON action tell a
    /// "click to close" apart from a fresh open. With `.transient`, the
    /// mouse-down on the status button already closed the popover before the
    /// action fires — without this guard the icon can only ever open. Scoped to
    /// the button path only: hotkey/reopen have no such mouse-down.
    private var lastCloseAt: Date = .distantPast
    /// Transparent anchor window used when the status icon isn't reachable;
    /// retained for the popover's lifetime and torn down on close.
    private var fallbackWindow: NSWindow?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.action = #selector(statusButtonClicked(_:))
            button.target = self
            button.toolTip = "GitDog"
            animator = SpriteAnimator(button: button)
        }

        popover.contentSize = Self.popoverSize
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(animator: animator)
                .preferredColorScheme(.dark)
        )
    }

    // MARK: open paths

    /// Deterministic "ensure the popover is shown and on-screen." Reused by the
    /// global hotkey, app reopen, and first-run (#30). Anchors to the menu bar
    /// icon when reachable, else to the floating fallback. Not a toggle.
    func openPopover() {
        if popover.isShown {
            // Already open (e.g. reopen while visible) → just raise it.
            activatePopover()
            return
        }
        if let (rect, view) = statusButtonAnchor() {
            popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
        } else {
            showFromFallbackAnchor()
        }
        activatePopover()
        NotificationCenter.default.post(name: .gitdogPopoverDidOpen, object: nil)
    }

    /// Toggle used by the global hotkey (open if closed, close if open).
    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover()
        }
    }

    func popoverDidClose(_ notification: Notification) {
        lastCloseAt = Date()
        fallbackWindow?.orderOut(nil)
        fallbackWindow = nil
        // First-run coachmark is a once-only nudge — don't let it return on the
        // next open within the same session.
        CoachmarkState.shared.showFirstRun = false
    }

    // MARK: button path (keeps the transient-close guard)

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        // The transient popover dismissed itself on this very click's
        // mouse-down; treat the action as "close", not "reopen".
        if Date().timeIntervalSince(lastCloseAt) < 0.25 {
            return
        }
        openPopover()
    }

    // MARK: anchoring

    /// The status button's anchor (rect + view) if it's genuinely on a visible
    /// part of the menu bar; nil when hidden behind the notch / off-screen /
    /// overflowed. Fail-safe: any uncertainty returns nil → use the fallback.
    private func statusButtonAnchor() -> (NSRect, NSView)? {
        guard statusItem.isVisible,
              let button = statusItem.button,
              let window = button.window
        else { return nil }
        let frame = window.frame
        guard !frame.isEmpty else { return nil }
        guard let screen = window.screen ?? NSScreen.main,
              screen.frame.intersects(frame)
        else { return nil }
        // On a notched display, treat an icon sitting in the notch gap as hidden.
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let notchMinX = left.maxX
            let notchMaxX = right.minX
            if frame.midX > notchMinX && frame.midX < notchMaxX { return nil }
        }
        return (button.bounds, button)
    }

    /// Show the popover anchored to a transparent 1×1 window pinned at the
    /// top-right of the active screen, just under the menu bar.
    private func showFromFallbackAnchor() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        let anchorRect = NSRect(x: vf.maxX - 24, y: vf.maxY - 1, width: 1, height: 1)

        let window = NSWindow(contentRect: anchorRect, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .statusBar
        let anchor = NSView(frame: NSRect(origin: .zero, size: anchorRect.size))
        window.contentView = anchor
        window.orderFrontRegardless()   // a popover needs its anchor in a visible window
        fallbackWindow = window

        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    /// `.accessory` apps are never active by default; without activation the
    /// popover window can't become key and keyboard input is dead. Activate
    /// BEFORE makeKey so a hotkey press from another frontmost app doesn't
    /// immediately auto-dismiss the transient popover.
    private func activatePopover() {
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }
}
