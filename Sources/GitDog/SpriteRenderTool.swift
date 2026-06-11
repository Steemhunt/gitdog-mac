import AppKit

/// Dev harness: `GITDOG_RENDER_SPRITES=/some/dir GitDog` renders every sprite
/// frame as a PNG (8× scale + 1× actual) into the directory and exits, so
/// frame art can be reviewed without squinting at the menu bar.
/// Not reachable in normal app runs.
enum SpriteRenderTool {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["GITDOG_RENDER_SPRITES"] else { return }
        let base = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        for state in DogState.allCases {
            for (i, cells) in Sprites.frames(for: state).enumerated() {
                let name = "\(state.rawValue)-\(i + 1)"
                write(cells: cells, scale: 8, to: base.appendingPathComponent("\(name)@8x.png"))
                write(cells: cells, scale: 1, to: base.appendingPathComponent("\(name).png"))
            }
        }
        print("sprites rendered to \(base.path)")
        exit(0)
    }

    private static func write(cells: [(Int, Int)], scale: CGFloat, to url: URL) {
        let size = NSSize(width: Sprites.canvas.width * scale,
                          height: Sprites.canvas.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor.black.setFill()
        let px = 2 * scale
        for (col, row) in cells {
            NSRect(x: CGFloat(col) * px, y: CGFloat(row) * px, width: px, height: px).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }
}
