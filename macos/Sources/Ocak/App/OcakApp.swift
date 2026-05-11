import CoreText
import SwiftUI

@main
struct OcakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        registerBundledFonts()
    }

    var body: some Scene {
        // No visible window — panels are managed by AppDelegate
        Settings { EmptyView() }
    }

    private func registerBundledFonts() {
        let fontNames = [
            "JetBrainsMono-Regular",
            "JetBrainsMono-Medium",
            "InstrumentSerif-Italic",
        ]
        for name in fontNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
