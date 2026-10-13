import AppKit
import ServiceManagement
import SwiftUI

/// Sofaonmac lives in the menu bar, just like Rugonmac: a native menu for everyday control,
/// plus a settings window. The chair itself stands on the desktop. Never shows in the Dock.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var controller: SofaController!
    private let model = SofaModel()

    private let menu = NSMenu()
    private var showItem: NSMenuItem!
    private var openItem: NSMenuItem!
    private var putBackItem: NSMenuItem!
    private var sizeItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = SofaController(model: model)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = AppDelegate.menuBarIcon()
        buildMenu()
        statusItem.menu = menu
        NSApp.mainMenu = AppDelegate.mainMenu()

        // First launch: open the settings once so it's clear where the app lives, and (when installed
        // properly) start at login, so the chair and everything on it is back after a restart.
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            if Bundle.main.bundlePath.hasPrefix("/Applications/") && !model.launchAtLogin {
                model.setLaunchAtLogin(true)
            }
            showSettings()
        }
    }

    /// Opening the app again (Finder, Spotlight) brings up the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    // MARK: Menu

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        // 1. the chair itself
        showItem = item("Sessel aufstellen", #selector(toggleSofa), key: "s", modifiers: [.command, .option])
        menu.addItem(showItem)
        openItem = item("Durchwühlen", #selector(openFan), key: "d", modifiers: [.command, .option])
        menu.addItem(openItem)
        putBackItem = item("Alles zurücklegen", #selector(putBackAll), key: "")
        menu.addItem(putBackItem)
        menu.addItem(.separator())

        // 2. what it looks like
        let chairs = NSMenuItem()
        let host = NSHostingView(rootView: MenuSofaPicker(model: model))
        host.frame.size = host.fittingSize
        chairs.view = host
        menu.addItem(chairs)
        let sizeParent = NSMenuItem(title: "Größe", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for s in SofaSize.allCases {
            let i = item(s.longTitle, #selector(pickSize(_:)), key: "")
            i.tag = s.rawValue
            sizeMenu.addItem(i)
            sizeItems.append(i)
        }
        sizeParent.submenu = sizeMenu
        menu.addItem(sizeParent)
        menu.addItem(.separator())

        // 3. app (options like always on top, login and the sofa folder live in the settings)
        menu.addItem(item("Über Sofaonmac", #selector(about), key: ""))
        menu.addItem(item("Einstellungen …", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Sofaonmac beenden", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String,
                      modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = modifiers
        i.target = self
        return i
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let n = model.items.count
        showItem.title = model.visible ? "Sessel wegräumen" : "Sessel aufstellen"
        openItem.title = n == 0 ? "Durchwühlen" : "Durchwühlen (\(n))"
        openItem.isEnabled = n > 0 && model.visible
        putBackItem.isEnabled = n > 0
        for i in sizeItems { i.state = i.tag == model.size.rawValue ? .on : .off }
    }

    @objc private func toggleSofa() { model.visible.toggle() }
    @objc private func openFan() { controller.openFan() }
    @objc private func putBackAll() { controller.putBackAll() }
    @objc private func pickSize(_ sender: NSMenuItem) { model.size = SofaSize(rawValue: sender.tag) ?? .medium }
    @objc private func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func about() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: Settings window

    private func showSettings() {
        if window == nil {
            let view = SettingsView(model: model,
                                    onResetPosition: { [weak self] in self?.controller.placeSofa(reset: true) },
                                    onPutBackAll: { [weak self] in self?.controller.putBackAll() })
            let host = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.title = "Sofaonmac"
            w.isMovableByWindowBackground = true
            w.isOpaque = false
            w.backgroundColor = .clear
            w.isReleasedWhenClosed = false
            w.setContentSize(host.view.fittingSize)
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Not visible (no Dock icon), but gives the settings window ⌘W and ⌘Q.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Fenster schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Sofaonmac beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        return main
    }

    /// Line-art chair with something thrown on it; template image so it follows the menu bar's color.
    static func menuBarIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let k = size / 18
            func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * k, y: y * k) }
            NSColor.black.set()
            // soft body
            let body = NSBezierPath(roundedRect: CGRect(x: 1.5 * k, y: 9 * k, width: 15 * k, height: 7.5 * k),
                                    xRadius: 3.2 * k, yRadius: 3.2 * k)
            // back, rising behind the seat
            let back = NSBezierPath()
            back.move(to: pt(2.5, 9.5))
            back.line(to: pt(3.2, 3.6))
            back.curve(to: pt(5, 2.4), controlPoint1: pt(3.3, 2.8), controlPoint2: pt(4, 2.4))
            back.line(to: pt(13.5, 2.4))
            back.curve(to: pt(15.5, 4.2), controlPoint1: pt(14.6, 2.4), controlPoint2: pt(15.5, 3))
            back.line(to: pt(15.5, 9.5))
            // seat cushion edge
            let seat = NSBezierPath()
            seat.move(to: pt(2.2, 9.5)); seat.line(to: pt(12, 9.5))
            // a little something thrown on it
            let thing = NSBezierPath(roundedRect: CGRect(x: 5 * k, y: 5.6 * k, width: 5 * k, height: 3.4 * k),
                                     xRadius: 0.6 * k, yRadius: 0.6 * k)
            var t = AffineTransform(translationByX: 7.5 * k, byY: 7.3 * k)
            t.rotate(byDegrees: -14)
            t.translate(x: -7.5 * k, y: -7.3 * k)
            thing.transform(using: t)
            for p in [body, back, seat, thing] {
                p.lineWidth = 1.3 * k
                p.lineCapStyle = .round
                p.lineJoinStyle = .round
                p.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Sofaonmac"
        return image
    }
}
