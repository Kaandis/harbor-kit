import AppKit
import Foundation
import ServiceManagement

/// How the Harbor hub and the apps share settings.
///
/// Harbor writes straight into an app's own preferences domain and then posts
/// a distributed notification naming that domain. The app, listening through
/// `listen()`, re-announces it as a local `UserDefaults.didChangeNotification`,
/// so its existing observers and `@AppStorage` views pick up the change
/// without knowing Harbor exists.
public enum SettingsBridge {
    public static let settingsChanged = Notification.Name("app.harbor.settingsChanged")
    /// Key under which an app publishes its permission status for Harbor to show.
    public static let permissionsKey = "harbor.permissions"

    // MARK: In the apps

    /// Call once at launch. Returns the observer token.
    ///
    /// Also answers Harbor when it's about to uninstall the app: launched
    /// with `UninstallRequest.argument`, the app removes its login item and
    /// exits at once; already running, it does the same on
    /// `UninstallRequest.notification` and quits.
    @MainActor
    @discardableResult
    public static func listen() -> NSObjectProtocol {
        let domain = Bundle.main.bundleIdentifier ?? ""
        if CommandLine.arguments.contains(UninstallRequest.argument) {
            UninstallRequest.prepare()
            exit(0)
        }
        DistributedNotificationCenter.default().addObserver(
            forName: UninstallRequest.notification, object: domain, queue: .main
        ) { _ in
            UninstallRequest.prepare()
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        return DistributedNotificationCenter.default().addObserver(
            forName: settingsChanged, object: domain, queue: .main
        ) { _ in
            CFPreferencesAppSynchronize(domain as CFString)
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        }
    }

    /// Records which permissions the app has, e.g. ["accessibility": true].
    public static func publishPermissions(_ status: [String: Bool]) {
        guard UserDefaults.standard.dictionary(forKey: permissionsKey) as? [String: Bool] != status else { return }
        UserDefaults.standard.set(status, forKey: permissionsKey)
    }

    // MARK: In Harbor

    /// Reads a value from the app's own file only, never the global domain
    /// (so a system-wide AppleLanguages doesn't look like the app's choice).
    public static func read(_ key: String, domain: String) -> Any? {
        CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    /// Writes (or with nil, removes) a value in another app's preferences.
    public static func write(_ value: Any?, key: String, domain: String) {
        CFPreferencesSetValue(key as CFString, value as CFPropertyList?, domain as CFString,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    /// Tells the app its preferences changed.
    public static func notify(domain: String) {
        DistributedNotificationCenter.default().postNotificationName(
            settingsChanged, object: domain, userInfo: nil, deliverImmediately: true)
    }

    public static func permissions(domain: String) -> [String: Bool] {
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return read(permissionsKey, domain: domain) as? [String: Bool] ?? [:]
    }
}

/// Before Harbor uninstalls an app, it asks the app to remove what only the
/// app itself can: its login item. macOS lets an app register and
/// unregister only itself, so without this the item would linger in System
/// Settings › Login Items after the app is gone.
public enum UninstallRequest {
    /// Posted by Harbor with the app's bundle identifier as the object.
    public static let notification = Notification.Name("app.harbor.prepareForUninstall")
    /// Harbor launches an app that isn't running with this argument.
    public static let argument = "--harbor-prepare-uninstall"
    /// A file in HarborKit's resource bundle that tells Harbor an app built
    /// with it understands the request, so Harbor never launches an app that
    /// would ignore it.
    public static let markerFile = "HarborKitFeatures.json"

    static func prepare() {
        if SMAppService.mainApp.status != .notRegistered {
            try? SMAppService.mainApp.unregister()
        }
    }

    /// Whether the app at `url` was built with a HarborKit that answers.
    public static func isSupported(byAppAt url: URL) -> Bool {
        let marker = url.appendingPathComponent("Contents/Resources/HarborKit_HarborKit.bundle/Contents/Resources/\(markerFile)")
        return FileManager.default.fileExists(atPath: marker.path)
    }
}

/// Opening Harbor from an app.
public enum HarborLink {
    public static let bundleIdentifier = "app.harbor.Harbor"

    public static var isHarborInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    /// Opens Harbor on this app's page. Returns false when Harbor isn't
    /// installed, so the app can show its own settings instead.
    @discardableResult
    public static func openSettings(appID: String) -> Bool {
        guard isHarborInstalled, let url = URL(string: "harbor://app/\(appID)") else { return false }
        return NSWorkspace.shared.open(url)
    }
}
