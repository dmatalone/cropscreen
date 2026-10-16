# Screen Crop Mirror (macOS)

A simple SwiftUI macOS application that selects a rectangle and displays a live cropped preview. It uses ScreenCaptureKit for screenshots approximately 8 times per second. It is not a native AirPlay sender.

## Build
1. Open Xcode 16 or newer and create a **macOS App** project named `ScreenCropMirror` using **SwiftUI** and **Swift**.
2. Delete the generated `ContentView.swift` and `ScreenCropMirrorApp.swift` files.
3. Add the supplied `ScreenCropMirror.swift` to the app target.
4. In Signing & Capabilities, disable **App Sandbox** for local testing, or configure screen-capture permissions as appropriate.
5. Build and Run. Grant Screen & System Audio Recording permission when prompted in macOS System Settings > Privacy & Security.

## Use with AirPlay
1. In macOS Control Center > Screen Mirroring, connect to the AirPlay TV and choose **Use As Separate Display** / extend display.
2. Keep the content you want to capture on your main Mac display.
3. Click **Select Screen Area** and drag a rectangle around that content.
4. Click **Start Preview**.
5. Move the app window to the AirPlay TV display and enlarge it. The cropped preview is the only content intentionally shown inside the preview window.

## Limitations
- Preview refreshes about 8 frames per second and is not suited to smooth video playback.
- Some DRM-protected videos (e.g. streaming TV) may appear black because macOS prevents capture.
- The overlay selects on the main display; other displays are not independently selectable.
- This is an Xcode source project, not a signed, ready-to-install .app.
- Do not use full desktop mirroring when you need to hide everything else: use an extended display instead.
