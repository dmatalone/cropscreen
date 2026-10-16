import SwiftUI
import AppKit
import ScreenCaptureKit

@main
struct ScreenCropMirrorApp: App {
    @StateObject private var model = CaptureModel()
    var body: some Scene {
        WindowGroup("Screen Crop Mirror") {
            ContentView().environmentObject(model)
                .frame(minWidth: 540, minHeight: 430)
        }
    }
}

@MainActor
final class CaptureModel: ObservableObject {
    @Published var image: NSImage?
    @Published var status = "Ready. Choose a crop area."
    @Published var crop = CGRect(x: 100, y: 100, width: 800, height: 450)
    @Published var running = false
    private var timer: Timer?
    private var busy = false

    func selectArea() {
        stop()
        guard let screen = NSScreen.main else { return }
        let overlay = SelectionOverlay(frame: screen.frame)
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = overlay
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlay.onSelect = { [weak self, weak window] rect in
            window?.orderOut(nil)
            guard rect.width > 20, rect.height > 20 else { return }
            // ScreenCaptureKit sourceRect is relative to the screen's top-left corner.
            let local = CGRect(x: rect.minX - screen.frame.minX,
                               y: screen.frame.maxY - rect.maxY,
                               width: rect.width, height: rect.height)
            self?.crop = local
            self?.status = "Area selected. Start the live preview."
        }
    }

    func start() {
        stop()
        running = true
        status = "Capturing selected area…"
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.captureFrame() }
        }
        Task { await captureFrame() }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        running = false
    }
    private func captureFrame() async {
        guard running, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
                status = "No display available"; stop(); return
            }
            let config = SCStreamConfiguration()
            config.sourceRect = crop
            config.width = max(2, Int(crop.width * 2))
            config.height = max(2, Int(crop.height * 2))
            config.showsCursor = true
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            status = "Live preview running"
        } catch {
            status = "Capture error: \(error.localizedDescription). Check Screen Recording permission."
            stop()
        }
    }
}

final class SelectionOverlay: NSView {
    var onSelect: ((CGRect) -> Void)?
    private var startPoint: NSPoint?
    private var endPoint: NSPoint?
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.30).setFill()
        bounds.fill()
        if let a = startPoint, let b = endPoint {
            let r = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
            NSColor.clear.setFill(); r.fill(using: .copy)
            NSColor.systemGreen.setStroke()
            let path = NSBezierPath(rect: r); path.lineWidth = 3; path.stroke()
        }
        let text = "Drag to select the area to show on TV"
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white, .font: NSFont.boldSystemFont(ofSize: 24)]
        text.draw(at: CGPoint(x: bounds.midX - 220, y: bounds.maxY - 75), withAttributes: attrs)
    }
    override func mouseDown(with event: NSEvent) { startPoint = convert(event.locationInWindow, from: nil); endPoint = startPoint; needsDisplay = true }
    override func mouseDragged(with event: NSEvent) { endPoint = convert(event.locationInWindow, from: nil); needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        endPoint = convert(event.locationInWindow, from: nil)
        if let a = startPoint, let b = endPoint {
            let rect = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
            onSelect?(convert(rect, to: nil))
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: CaptureModel
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "rectangle.dashed.badge.record").font(.title)
                Text("Screen Crop Mirror").font(.title2.bold())
                Spacer()
                Text(model.running ? "LIVE" : "READY")
                    .font(.caption.bold()).foregroundStyle(model.running ? .green : .secondary)
            }
            HStack {
                Button("Select Screen Area") { model.selectArea() }
                    .buttonStyle(.borderedProminent)
                Button(model.running ? "Stop Preview" : "Start Preview") {
                    model.running ? model.stop() : model.start()
                }
                Spacer()
            }
            ZStack {
                Color.black
                if let image = model.image {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "display").font(.system(size: 48))
                        Text("Your cropped screen appears here")
                    }.foregroundStyle(.white.opacity(0.75))
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(model.status).font(.caption).foregroundStyle(.secondary)
            Text("AirPlay: macOS Control Center → Screen Mirroring → select your TV. Use the TV as an extended display and move this preview window onto it. Then enlarge the window to fill the TV.")
                .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(18)
    }
}
