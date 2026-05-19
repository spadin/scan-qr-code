import AppKit

// SwiftPM executable entry point. The bundle's Info.plist also sets
// `LSUIElement` so the app launches as a menu bar agent with no Dock icon;
// `.accessory` in AppDelegate is the belt-and-suspenders equivalent.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
