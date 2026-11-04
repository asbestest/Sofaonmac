import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--snapshot") {
    MainActor.assumeIsolated { Snapshot.run(outputDir: args.count > i + 1 ? args[i + 1] : ".") }
    exit(0)
}
if let i = args.firstIndex(of: "--icon") {
    AppIcon.render(to: args.count > i + 1 ? args[i + 1] : "icon.png")
    exit(0)
}
if let i = args.firstIndex(of: "--cutout"), args.count > i + 2 {
    let lift = args.firstIndex(of: "--lift").flatMap { args.count > $0 + 1 ? Float(args[$0 + 1]) : nil } ?? 0
    exit(Cutout.run(input: args[i + 1], output: args[i + 2], lift: lift) ? 0 : 1)
}

EarlierSettings.takeOver()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
