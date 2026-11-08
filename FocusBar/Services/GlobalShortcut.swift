import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Default: ⌃⌥Space. Users can change it in Settings.
    static let captureDistraction = Self(
        "captureDistraction",
        default: .init(.space, modifiers: [.control, .option])
    )
}
