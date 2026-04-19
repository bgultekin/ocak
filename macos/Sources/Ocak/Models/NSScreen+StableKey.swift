import AppKit

extension NSScreen {
    /// A unique key for this screen that distinguishes same-model monitors by position.
    /// Stable across app launches for the same physical arrangement; resets when rearranged.
    var stableKey: String {
        "\(localizedName)@\(Int(frame.origin.x)),\(Int(frame.origin.y))"
    }
}
