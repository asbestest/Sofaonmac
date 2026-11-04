import Foundation

/// The bundle identifier changed once. The first time the app runs under the new one, it takes over
/// what was saved under the old one: any `….sofaonmac` domain in ~/Library/Preferences that isn't its own.
enum EarlierSettings {
    static func takeOver() {
        let d = UserDefaults.standard
        guard let own = Bundle.main.bundleIdentifier, !d.bool(forKey: "tookOverEarlierSettings") else { return }
        d.set(true, forKey: "tookOverEarlierSettings")
        let prefs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: prefs.path)) ?? []
        for file in files where file.hasSuffix(".sofaonmac.plist") {
            let id = String(file.dropLast(".plist".count))
            guard id != own, let old = d.persistentDomain(forName: id) else { continue }
            for (key, value) in old where d.object(forKey: key) == nil { d.set(value, forKey: key) }
        }
    }
}
