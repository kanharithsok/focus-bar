import AppKit
import SwiftUI

@MainActor
final class CapturePanelController {
    private var panel: NSPanel?
    private var onSave: ((String) -> Void)?

    func show(focusObject: String?, onSave: @escaping (String) -> Void) {
        hide()
        self.onSave = onSave

        let view = CaptureView(
            focusObject: focusObject,
            onSave: { [weak self] text in
                self?.finish(text)
            },
            onCancel: { [weak self] in
                self?.hide()
            }
        )

        let hostingController = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 170),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = hostingController
        panel.setContentSize(hostingController.view.fittingSize)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(
                NSPoint(
                    x: visible.midX - size.width / 2,
                    y: visible.maxY - size.height - 32
                )
            )
        }

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        onSave = nil
    }

    private func finish(_ text: String) {
        let save = onSave
        hide()
        save?(text)
    }
}
