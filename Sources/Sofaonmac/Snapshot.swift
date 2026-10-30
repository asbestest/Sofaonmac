import AppKit
import SwiftUI

/// Debug helpers that render without touching the real sofa:
/// `Sofaonmac --snapshot <dir>` writes the sofa (empty, full, drop hover) and the fan as PNGs,
/// using a throwaway sofa folder with demo files.
@MainActor
enum Snapshot {
    static func run(outputDir: String) {
        let dir = URL(fileURLWithPath: outputDir)
        let bg = Color(red: 0.35, green: 0.47, blue: 0.62)

        save(SofaView(model: demoModel(0)).background(bg), dir.appendingPathComponent("1-empty.png"))
        save(SofaView(model: demoModel(7)).background(bg), dir.appendingPathComponent("2-pile.png"))
        for style in SofaStyle.all {
            let m = demoModel(5)
            m.style = style
            save(SofaView(model: m).background(bg), dir.appendingPathComponent("2-pile-\(style.id).png"))
            save(SofaView(model: m), dir.appendingPathComponent("7-clear-\(style.id).png"))   // transparent, for composing
        }

        let hover = demoModel(3)
        hover.dragActive = true
        hover.dropHover = true
        save(SofaView(model: hover).padding(20).background(bg), dir.appendingPathComponent("3-hover.png"))
        // exactly as the window shows it: clipped to the window, on the desktop color — for each chair, plain and hovered
        for style in SofaStyle.all {
            for hovered in [false, true] {
                let m = demoModel(3)
                m.style = style
                m.dragActive = hovered
                m.dropHover = hovered
                let c = m.style.canvas
                save(SofaView(model: m).frame(width: c.width, height: c.height, alignment: .topLeading).clipped()
                        .background(bg),
                     dir.appendingPathComponent("8-window-\(style.id)\(hovered ? "-hover" : "").png"))
            }
        }

        for n in [4, 9] {
            let m = demoModel(n)
            let state = FanState()
            state.open = true
            let size = CGSize(width: 1440, height: 900)
            let canvas = m.style.canvas
            let sofaOrigin = CGPoint(x: size.width - canvas.width - 20, y: size.height - canvas.height - 4)
            let fan = ZStack(alignment: .topLeading) {
                bg
                SofaView(model: m).position(x: sofaOrigin.x + canvas.width / 2, y: sofaOrigin.y + canvas.height / 2)
                FanView(model: m, state: state,
                        sofaPoint: CGPoint(x: sofaOrigin.x + m.style.chair.midX, y: sofaOrigin.y + m.style.chair.minY),
                        onPutBack: { _ in }, onPutBackAll: {}, onClose: {})
            }.frame(width: size.width, height: size.height)
            save(fan, dir.appendingPathComponent("4-fan-\(n).png"), scale: 1)
        }
        save(Image(nsImage: AppDelegate.menuBarIcon(size: 180)).padding(10).background(.white),
             dir.appendingPathComponent("5-menuicon.png"))
        // the settings window, drawn through AppKit (its controls are AppKit-backed)
        let settings = NSHostingView(rootView: SettingsView(model: demoModel(4), onResetPosition: {}, onPutBackAll: {})
            .background(Color(white: 0.93)))
        settings.frame.size = settings.fittingSize
        let win = NSWindow(contentRect: settings.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = settings
        settings.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        if let rep = settings.bitmapImageRepForCachingDisplay(in: settings.bounds) {
            settings.cacheDisplay(in: settings.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("6-settings.png"))
        }
        print("Wrote snapshots to \(dir.path)")
    }

    private static func save(_ view: some View, _ url: URL, scale: CGFloat = 2) {
        let r = ImageRenderer(content: view)
        r.scale = scale
        guard let cg = r.cgImage else { print("render failed: \(url.lastPathComponent)"); return }
        try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
    }

    /// A sofa in a temp folder with `n` demo files: pictures, a text, a folder, a PDF …
    static func demoModel(_ n: Int) -> SofaModel {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("sofa-demo-\(UUID().uuidString)/Auf dem Sofa", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for i in 0..<n { makeDemoFile(i, in: folder) }
        let m = SofaModel(folder: folder)
        // previews come from Quick Look in the background; give them a moment so they're in the picture
        let deadline = Date().addingTimeInterval(n == 0 ? 0 : 3)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return m
    }

    private static func makeDemoFile(_ i: Int, in folder: URL) {
        let hue = Double(i) * 0.13
        switch i % 5 {
        case 0, 3:
            let size = i % 2 == 0 ? CGSize(width: 1200, height: 800) : CGSize(width: 800, height: 1000)
            let img = NSImage(size: size, flipped: true) { r in
                NSGradient(starting: NSColor(calibratedHue: hue, saturation: 0.5, brightness: 0.95, alpha: 1),
                           ending: NSColor(calibratedHue: hue + 0.1, saturation: 0.7, brightness: 0.6, alpha: 1))?.draw(in: r, angle: 70)
                NSColor(white: 1, alpha: 0.85).setFill()
                NSBezierPath(ovalIn: CGRect(x: r.width * 0.6, y: r.height * 0.15, width: r.width * 0.2, height: r.width * 0.2)).fill()
                return true
            }
            if let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("Urlaub \(i + 1).png"))
            }
        case 1:
            try? "Einkaufsliste\n\n- Milch\n- Brot\n- Sofakissen\n".write(to: folder.appendingPathComponent("Einkaufsliste \(i).txt"), atomically: true, encoding: .utf8)
        case 2:
            try? FileManager.default.createDirectory(at: folder.appendingPathComponent("Projekte \(i)"), withIntermediateDirectories: true)
        default:
            let data = NSMutableData()
            var box = CGRect(x: 0, y: 0, width: 595, height: 842)
            if let consumer = CGDataConsumer(data: data), let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) {
                ctx.beginPDFPage(nil)
                ctx.setFillColor(NSColor(calibratedHue: hue, saturation: 0.6, brightness: 0.7, alpha: 1).cgColor)
                for k in 0..<12 { ctx.fill(CGRect(x: 60, y: 760 - CGFloat(k) * 50, width: CGFloat(200 + (k * 37) % 280), height: 18)) }
                ctx.endPDFPage()
                ctx.closePDF()
            }
            data.write(to: folder.appendingPathComponent("Rechnung \(i).pdf"), atomically: true)
        }
    }
}
