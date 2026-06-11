import AppKit
import SwiftUI

/// Owns the NSStatusItem (menu bar dog) and the NSPopover that anchors to it.
/// The animated sprite states land with gitdog-mac#3; the scaffold ships a
/// static template glyph so the surface is fully wired end to end.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    /// Single source of truth for the popover size (PopoverRootView matches it).
    static let popoverSize = NSSize(width: 360, height: 420)

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private(set) var animator: SpriteAnimator?
    /// Set when the transient popover closes; lets the button action tell a
    /// "click to close" apart from a fresh open. With `.transient`, the
    /// mouse-down on the status button already closed the popover before the
    /// action fires — without this guard the icon can only ever open.
    private var lastCloseAt: Date = .distantPast

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "GitDog"
            animator = SpriteAnimator(button: button)
        }

        popover.contentSize = Self.popoverSize
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverRootView())
    }

    func popoverDidClose(_ notification: Notification) {
        lastCloseAt = Date()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        // The transient popover dismissed itself on this very click's
        // mouse-down; treat the action as "close", not "reopen".
        if Date().timeIntervalSince(lastCloseAt) < 0.25 {
            return
        }
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        // .accessory apps are never active by default; without activation the
        // popover window can't become key and keyboard input is dead.
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }

}
