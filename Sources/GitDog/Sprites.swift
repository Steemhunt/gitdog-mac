import AppKit

/// The menu bar dog's animation states.
/// Mapping (EPIC + design package `design/icons/strip-*.jpg`):
/// - `sleep`   — idle, nothing to do (2 frames: curled up, Z toggle)
/// - `arrived` — unread request(s) waiting (2 frames: sitting alert, bone blink)
/// - `wag`     — a payout just landed (3 frames: tail positions), transient
/// - `run`     — cash-out success zoomies (4-frame run cycle), transient
enum DogState: String, CaseIterable {
    case sleep, arrived, wag, run
}

/// Pixel-art sprite frames, hand-traced from the design strips onto a 9×9
/// cell grid (2pt cells on the 18pt menu bar canvas). Cells are (col, row)
/// with row 0 at the BOTTOM. All frames render as template images so the
/// silhouette adapts to light/dark menu bars.
enum Sprites {
    static let canvas = NSSize(width: 18, height: 18)
    private static let cell: CGFloat = 2

    // MARK: frame data

    /// Lying curled, head left, tail tucked.
    private static let sleepBody: [(Int, Int)] = [
        // head (left, resting on paws)
        (1, 3), (2, 3), (1, 2), (2, 2),
        // ear nub
        (2, 4),
        // body mound
        (3, 3), (4, 3), (5, 3), (6, 3),
        (3, 2), (4, 2), (5, 2), (6, 2), (7, 2),
        // tail curled along the body
        (7, 3), (8, 2),
    ]

    /// Sitting upright, facing left, ears perked (from the scaffold glyph).
    private static let sittingAlert: [(Int, Int)] = [
        // head + snout
        (1, 5), (2, 5), (3, 5), (4, 5),
        (2, 6), (3, 6),
        // perked ears
        (2, 7), (4, 7),
        // chest + body
        (3, 4), (4, 4), (5, 4), (6, 4),
        (4, 3), (5, 3), (6, 3),
        // tail up
        (7, 5), (7, 6),
        // legs
        (4, 2), (6, 2), (4, 1), (6, 1),
    ]

    /// Standing side profile (shared base for wag/run), facing left.
    /// Tail and legs are appended per frame.
    private static let standingCore: [(Int, Int)] = [
        // head + snout
        (1, 4), (2, 4), (1, 5), (2, 5),
        // ear
        (2, 6),
        // body
        (3, 4), (4, 4), (5, 4), (6, 4),
        (3, 5), (4, 5), (5, 5), (6, 5),
    ]

    static func frames(for state: DogState) -> [[(Int, Int)]] {
        switch state {
        case .sleep:
            return [
                sleepBody,
                sleepBody + [(6, 5), (7, 6), (8, 7)], // rising-Z dots
            ]
        case .arrived:
            return [
                sittingAlert,
                sittingAlert + [(5, 8), (6, 8), (7, 8)], // bone blink above the back, clear of the ears
            ]
        case .wag:
            let legs = [(3, 2), (3, 3), (6, 2), (6, 3)]
            return [
                standingCore + legs + [(7, 4), (8, 3)], // tail low
                standingCore + legs + [(7, 5), (7, 6)], // tail up
                standingCore + legs + [(7, 4), (8, 5)], // tail mid-high
            ]
        case .run:
            return [
                // extended stride
                standingCore + [(2, 2), (3, 3), (6, 3), (7, 2), (8, 4)],
                // landing
                standingCore + [(3, 2), (3, 3), (6, 2), (6, 3), (8, 4)],
                // gathered under the body
                standingCore + [(4, 2), (4, 3), (5, 2), (5, 3), (8, 5)],
                // pushing off
                standingCore + [(3, 2), (3, 3), (6, 2), (6, 3), (8, 5)],
            ]
        }
    }

    // MARK: rendering

    static func image(for cells: [(Int, Int)]) -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { _ in
            NSColor.black.setFill()
            for (col, row) in cells {
                NSRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell,
                       width: cell, height: cell).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// All frames for a state, pre-rendered.
    static func images(for state: DogState) -> [NSImage] {
        frames(for: state).map(image(for:))
    }
}
