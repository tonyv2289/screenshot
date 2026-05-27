import Foundation

enum SharedContainer {
    private static let appGroupInfoKey = "AppGroupIdentifier"
    private static let fallbackAppGroupId = "group.com.tonyv2289.screenshotroll"

    static var sharedAppGroupId: String {
        let configuredId = Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String
        let trimmed = configuredId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallbackAppGroupId : trimmed
    }

    static func appGroupURL() -> URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: sharedAppGroupId) else {
            fatalError("App Group container missing. Check capabilities and identifier.")
        }
        return url
    }

    static func sharedInboxURL() -> URL {
        let url = appGroupURL().appendingPathComponent("SharedInbox", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static func databaseURL() -> URL {
        // Keep DB in app sandbox Application Support by default
        let base = appSupportURL()
        let url = base.appendingPathComponent("screenshot_roll.sqlite")
        return url
    }

    static func assetsDirectoryURL() -> URL {
        let base = appSupportURL()
        let dir = base.appendingPathComponent("Assets", isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    static func appSupportURL() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let base = urls[0].appendingPathComponent("ScreenshotRoll", isDirectory: true)
        ensureDirectory(base)
        return base
    }

    private static func ensureDirectory(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.protectionKey: FileProtectionType.complete
            ])
        }
    }
}
