import AppKit
import Carbon.HIToolbox

/// A single system-wide hotkey via the Carbon Event Manager (#29). Carbon's
/// `RegisterEventHotKey` is the only dependency-free way to get a true global
/// hotkey, and unlike `NSEvent.addGlobalMonitorForEvents` it needs NO
/// Accessibility permission. The default — ⌥⌘G — opens GitDog from anywhere,
/// so a menu bar icon hidden behind the notch is never the only way in.
@MainActor
final class GlobalHotKey {
    /// Display label for the binding — the single source the first-run coachmark
    /// (#30) reads so its copy can never drift from the real key.
    static let displayLabel = "⌥⌘G"

    private static let signature = OSType(0x47_44_4F_47) // 'GDOG'
    private static let hotKeyID: UInt32 = 1
    /// The live instance, so the C event callback (which can't capture context)
    /// can route the press back. Only one global hotkey exists.
    private static weak var shared: GlobalHotKey?

    private let onPressed: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    var isRegistered: Bool { hotKeyRef != nil }

    /// Register ⌥⌘G. Idempotent. Logs (does not crash) if the combo is already
    /// owned by another app so a conflict is diagnosable.
    func register() {
        guard hotKeyRef == nil else { return }
        Self.shared = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // Install the handler once for the app's event target.
        if handlerRef == nil {
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard id.signature == GlobalHotKey.signature, id.id == GlobalHotKey.hotKeyID else {
                    return OSStatus(eventNotHandledErr)
                }
                // Carbon delivers on the main thread; hop to the main actor to
                // touch UI safely.
                Task { @MainActor in GlobalHotKey.shared?.onPressed() }
                return noErr
            }, 1, &eventType, nil, &handlerRef)
        }

        let id = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let modifiers = UInt32(cmdKey | optionKey)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_G), modifiers,
                                         id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            hotKeyRef = nil
            NSLog("GitDog: global hotkey \(Self.displayLabel) registration failed (status \(status)) — likely already in use by another app")
        }
    }

    /// Remove the hotkey (keeps the installed handler; re-register is cheap).
    /// Called from the Settings toggle and `applicationWillTerminate`; the
    /// instance lives for the app's lifetime, so there's no deinit cleanup
    /// (a nonisolated deinit can't touch these @MainActor Carbon refs anyway,
    /// and the OS reclaims them on process exit).
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}

/// App-wide hotkey preference (#29). NOT the per-user/per-host LocalSettings —
/// a hotkey binding is global to the install, and must be readable while
/// signed out. Default ON.
enum HotKeyPreference {
    private static let key = "gd.hotkey.enabled"
    static var enabled: Bool {
        get {
            UserDefaults.standard.object(forKey: key) as? Bool ?? true
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
