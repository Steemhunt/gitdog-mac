import AppKit
import SwiftUI

/// Owns the NSStatusItem (menu bar dog) and the NSPopover that anchors to it.
/// The animated sprite states land with gitdog-mac#3; the scaffold ships a
/// static template glyph so the surface is fully wired end to end.
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = Self.menuBarIcon()
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.toolTip = "GitDog"
        }

        popover.contentSize = NSSize(width: 360, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverRootView())
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Static sitting-dog silhouette as a template image (adapts to light/dark
    /// menu bars). Drawn in code so the scaffold has no asset-pipeline
    /// dependency; replaced by the traced sprite frames in gitdog-mac#3.
    private static func menuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let px: CGFloat = 2 // chunky 2pt "pixels" on the 18pt canvas
            // (col, row) cells of a 9x9 grid, row 0 = bottom
            let cells: [(Int, Int)] = [
                // head + snout (left-facing)
                (2, 5), (3, 5), (4, 5), (1, 5),
                (2, 6), (3, 6),
                // ears
                (2, 7), (4, 7),
                // body
                (3, 4), (4, 4), (5, 4), (6, 4),
                (4, 3), (5, 3), (6, 3),
                // tail up
                (7, 5), (7, 6),
                // legs
                (4, 2), (6, 2), (4, 1), (6, 1)
            ]
            for (col, row) in cells {
                NSRect(x: CGFloat(col) * px, y: CGFloat(row) * px, width: px, height: px).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
