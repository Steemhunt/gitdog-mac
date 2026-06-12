import AppKit

/// The menu bar dog's animation states.
/// - `sleep`   — idle (2 frames: curled up, Z toggle)
/// - `arrived` — unread request(s) waiting (2 frames: sitting alert, bone blink)
/// - `wag`     — payout landed (3 tail positions), transient
/// - `run`     — cash-out zoomies (4-frame run cycle), transient
enum DogState: String, CaseIterable {
    case sleep, arrived, wag, run
}

/// Smooth template silhouettes drawn with bezier paths on the 18pt canvas
/// (gitdog-mac#12 — pixel art is illegible at menu bar size; RunCat-style
/// readable anatomy instead). Pixel art remains the brand everywhere else.
/// All frames render as template images (light/dark adaptive).
enum Sprites {
    static let canvas = NSSize(width: 18, height: 18)

    static func frameCount(for state: DogState) -> Int {
        switch state {
        case .sleep, .arrived: 2
        case .wag: 3
        case .run: 4
        }
    }

    static func images(for state: DogState) -> [NSImage] {
        (0..<frameCount(for: state)).map { image(for: state, frame: $0) }
    }

    static func image(for state: DogState, frame: Int) -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { _ in
            draw(state: state, frame: frame)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Draws one frame in an 18×18 coordinate space (origin bottom-left).
    /// Callers may scale the CTM first (render harness does 8×).
    static func draw(state: DogState, frame: Int) {
        NSColor.black.set()
        switch state {
        case .sleep: drawSleep(zVisible: frame == 1)
        case .arrived: drawSitting(boneVisible: frame == 1)
        case .wag: drawStanding(tailFrame: frame)
        case .run: drawRun(frame: frame)
        }
    }

    // MARK: shared parts (dog faces right)

    private static func fillEllipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
    }

    private static func capsule(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h),
                     xRadius: min(w, h) / 2, yRadius: min(w, h) / 2).fill()
    }

    /// Thick round-capped stroke — used for legs and tails (RunCat-style limbs).
    private static func limb(from a: NSPoint, to b: NSPoint, width: CGFloat = 1.8) {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: b)
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func triangle(_ p1: NSPoint, _ p2: NSPoint, _ p3: NSPoint) {
        let path = NSBezierPath()
        path.move(to: p1); path.line(to: p2); path.line(to: p3)
        path.close(); path.fill()
    }

    /// Head with snout and one visible ear, centered at `center`.
    private static func head(center: NSPoint, earUp: Bool) {
        fillEllipse(center.x - 3, center.y - 2.8, 6, 5.6)
        // snout wedge
        capsule(center.x + 1.6, center.y - 1.6, 3.0, 2.4)
        // ear (triangle on top, leaning back slightly)
        if earUp {
            triangle(NSPoint(x: center.x - 2.2, y: center.y + 1.8),
                     NSPoint(x: center.x - 1.1, y: center.y + 5.2),
                     NSPoint(x: center.x + 0.6, y: center.y + 2.4))
        } else {
            // relaxed ear, folded back
            triangle(NSPoint(x: center.x - 2.4, y: center.y + 1.6),
                     NSPoint(x: center.x - 3.4, y: center.y + 4.2),
                     NSPoint(x: center.x - 0.2, y: center.y + 2.4))
        }
    }

    // MARK: states

    private static func drawStanding(tailFrame: Int) {
        // legs first (behind the body)
        limb(from: NSPoint(x: 6.0, y: 6.5), to: NSPoint(x: 5.6, y: 1.2))
        limb(from: NSPoint(x: 8.0, y: 6.5), to: NSPoint(x: 8.2, y: 1.2))
        limb(from: NSPoint(x: 11.2, y: 6.5), to: NSPoint(x: 11.0, y: 1.2))
        limb(from: NSPoint(x: 13.0, y: 6.5), to: NSPoint(x: 13.4, y: 1.2))
        // body
        capsule(4.2, 5.6, 10.8, 4.8)
        // head
        head(center: NSPoint(x: 13.2, y: 10.6), earUp: true)
        // tail — three wag positions
        let tip: NSPoint = switch tailFrame {
        case 0: NSPoint(x: 1.0, y: 5.6)    // low
        case 1: NSPoint(x: 1.6, y: 13.0)   // high
        default: NSPoint(x: 0.6, y: 9.6)   // mid
        }
        limb(from: NSPoint(x: 4.8, y: 8.6), to: tip, width: 1.6)
    }

    private static func drawRun(frame: Int) {
        // slight vertical bounce on the gathered frames
        let bounce: CGFloat = (frame == 2) ? 0.8 : 0
        let hipY = 6.2 + bounce
        let frontHip = NSPoint(x: 12.4, y: hipY)
        let backHip = NSPoint(x: 6.2, y: hipY)

        // leg positions per phase: extended → landing → gathered → push-off
        switch frame {
        case 0: // full stride
            limb(from: frontHip, to: NSPoint(x: 16.4, y: 1.4))
            limb(from: frontHip, to: NSPoint(x: 14.2, y: 1.0))
            limb(from: backHip, to: NSPoint(x: 2.2, y: 1.4))
            limb(from: backHip, to: NSPoint(x: 4.0, y: 1.0))
        case 1: // landing
            limb(from: frontHip, to: NSPoint(x: 14.6, y: 1.0))
            limb(from: frontHip, to: NSPoint(x: 12.6, y: 1.2))
            limb(from: backHip, to: NSPoint(x: 4.4, y: 1.0))
            limb(from: backHip, to: NSPoint(x: 6.4, y: 1.2))
        case 2: // gathered under the body
            limb(from: frontHip, to: NSPoint(x: 11.0, y: 1.6))
            limb(from: frontHip, to: NSPoint(x: 12.8, y: 2.0))
            limb(from: backHip, to: NSPoint(x: 7.6, y: 1.6))
            limb(from: backHip, to: NSPoint(x: 6.0, y: 2.0))
        default: // push-off
            limb(from: frontHip, to: NSPoint(x: 15.2, y: 1.8))
            limb(from: frontHip, to: NSPoint(x: 13.0, y: 1.0))
            limb(from: backHip, to: NSPoint(x: 3.2, y: 2.2))
            limb(from: backHip, to: NSPoint(x: 5.2, y: 1.0))
        }
        // body leans into the run
        capsule(4.0, 5.4 + bounce, 11.0, 4.6)
        head(center: NSPoint(x: 13.4, y: 9.8 + bounce), earUp: false)
        // tail streams behind
        limb(from: NSPoint(x: 4.6, y: 8.2 + bounce), to: NSPoint(x: 0.8, y: 10.4 + bounce), width: 1.6)
    }

    private static func drawSitting(boneVisible: Bool) {
        // body: wide-bottomed rounded wedge (haunch up to the shoulders)
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 3.0, y: 1.2))
        body.curve(to: NSPoint(x: 9.4, y: 11.0),
                   controlPoint1: NSPoint(x: 3.0, y: 6.8),
                   controlPoint2: NSPoint(x: 6.0, y: 10.6))
        body.curve(to: NSPoint(x: 13.2, y: 1.2),
                   controlPoint1: NSPoint(x: 12.4, y: 11.0),
                   controlPoint2: NSPoint(x: 13.2, y: 6.0))
        body.close()
        body.fill()
        // rounded base so the wedge sits naturally
        fillEllipse(2.8, 0.6, 10.6, 3.6)
        // head clearly above the body
        fillEllipse(6.6, 9.6, 6.4, 5.8)
        // snout to the right
        capsule(11.6, 11.0, 2.8, 2.2)
        // two upright ears
        triangle(NSPoint(x: 6.8, y: 13.6), NSPoint(x: 7.6, y: 17.2), NSPoint(x: 9.4, y: 14.4))
        triangle(NSPoint(x: 10.2, y: 14.4), NSPoint(x: 11.6, y: 17.0), NSPoint(x: 12.6, y: 13.6))
        // tail curled around the haunch
        limb(from: NSPoint(x: 3.4, y: 1.8), to: NSPoint(x: 0.8, y: 4.4), width: 1.6)

        if boneVisible {
            drawBone(center: NSPoint(x: 15.2, y: 16.4))
        }
    }

    /// Tiny bone: bar + four end knobs.
    private static func drawBone(center: NSPoint) {
        capsule(center.x - 2.0, center.y - 0.55, 4.0, 1.1)
        for dx in [-2.0, 2.0] as [CGFloat] {
            for dy in [-0.6, 0.6] as [CGFloat] {
                fillEllipse(center.x + dx - 0.75, center.y + dy - 0.75, 1.5, 1.5)
            }
        }
    }

    private static func drawSleep(zVisible: Bool) {
        // curled mound
        fillEllipse(2.6, 1.6, 11.8, 6.6)
        // head resting on the near side, ear relaxed
        fillEllipse(9.6, 4.2, 5.4, 4.6)
        triangle(NSPoint(x: 11.4, y: 7.6),
                 NSPoint(x: 12.2, y: 10.2),
                 NSPoint(x: 13.8, y: 7.8))
        // tail tucked along the front
        limb(from: NSPoint(x: 3.4, y: 2.6), to: NSPoint(x: 7.2, y: 1.6), width: 1.6)

        if zVisible {
            drawZ(at: NSPoint(x: 13.6, y: 12.2), size: 2.2)
            drawZ(at: NSPoint(x: 15.6, y: 15.2), size: 1.5)
        }
    }

    /// A little "z" glyph drawn with strokes.
    private static func drawZ(at origin: NSPoint, size: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: origin.x, y: origin.y + size))
        path.line(to: NSPoint(x: origin.x + size, y: origin.y + size))
        path.line(to: NSPoint(x: origin.x, y: origin.y))
        path.line(to: NSPoint(x: origin.x + size, y: origin.y))
        path.lineWidth = 0.9
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}
