import AppKit

// Menu-bar-only app: no Dock icon, no main window. LSUIElement in Info.plist
// hides the Dock icon for bundled builds; .accessory covers `swift run` too.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
