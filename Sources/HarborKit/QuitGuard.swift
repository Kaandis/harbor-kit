import AppKit
import Darwin

/// Keeps menu bar apps running when macOS quits them as idle.
///
/// On macOS 27 the App Intents daemon (`linkd`) sometimes adopts an app that's
/// already running, and once its requests finish it sends the app a Quit
/// Apple event as if it had launched it in the background. To the user the
/// app just disappears. Our apps live in the menu bar and are never idle, so
/// they turn that one quit down; quitting from the menu, from Harbor, at
/// logout or by anyone else goes ahead as usual.
public enum QuitGuard {
    /// Return this from `applicationShouldTerminate(_:)`.
    @MainActor
    public static func reply() -> NSApplication.TerminateReply {
        isIdleQuitFromSystem ? .terminateCancel : .terminateNow
    }

    static var isIdleQuitFromSystem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEQuitApplication),
              let pid = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value,
              pid > 0 else { return false }
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return false }
        return String(cString: path).hasSuffix("/linkd")
    }
}
