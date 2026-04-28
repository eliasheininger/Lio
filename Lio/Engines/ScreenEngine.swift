import ScreenCaptureKit
import AppKit
import CoreGraphics

enum ScreenCaptureError: Error, LocalizedError {
    case permissionDenied
    case noFrontmostWindow
    case captureFailure
    case requiresMacOS14

    var errorDescription: String? {
        switch self {
        case .permissionDenied:  return "Screen Recording permission is required"
        case .noFrontmostWindow: return "No frontmost window found"
        case .captureFailure:    return "Failed to capture screenshot"
        case .requiresMacOS14:   return "Screen capture requires macOS 14.2 or later"
        }
    }
}

/// Result of a single screen capture, containing the API-ready JPEG and the
/// geometry needed to convert image-space coordinates back to screen-space.
struct CaptureResult {
    /// Base64-encoded PNG string (no data URL prefix), ready for the Anthropic API.
    let base64Image: String
    /// Size of the JPEG image sent to Claude (may be smaller than native due to resizing).
    let apiImageSize: CGSize
    /// Top-left corner of the captured window in macOS bottom-left screen coordinates.
    /// Derived from SCWindow.frame: (frame.minX, frame.maxY) — the top edge in bottom-left coords.
    let windowOriginTopLeft: CGPoint
    /// Width and height of the window in screen points.
    let windowSizePoints: CGSize
    /// The resized CGImage before JPEG encoding. Used by GridEngine to annotate without re-decoding.
    let cgImage: CGImage?
}

/// Captures the frontmost macOS window as a PNG suitable for the Claude multimodal API.
/// Requires Screen Recording permission and macOS 14.2+.
///
/// Tune CAPTURE_MAX_LONG_SIDE to trade off token cost vs. recognition quality:
///   1280 — original default, high accuracy, ~700 KB
///   1024 — good balance, ~450 KB  ← current setting
///    900 — smaller, still reliable for most UI
///    720 — minimum recommended; small text may degrade
private let CAPTURE_MAX_LONG_SIDE = 1024

final class ScreenEngine {

    /// Returns true if Screen Recording permission has been granted.
    static func hasPermission() -> Bool {
        if #available(macOS 14.2, *) {
            return CGPreflightScreenCaptureAccess()
        }
        // On macOS 13 we probe by checking if SCShareableContent can enumerate content
        return true   // will fail gracefully at capture time if denied
    }

    /// Triggers the system Screen Recording permission prompt (macOS 14.2+).
    static func requestPermission() {
        if #available(macOS 14.2, *) {
            CGRequestScreenCaptureAccess()
        }
    }

    /// Capture the full main display (excluding Lio's own windows) so Claude
    /// can see everything — Dock, menu bar, all open windows.
    func captureWindow() async throws -> CaptureResult {
        let maxLongSide = CAPTURE_MAX_LONG_SIDE
        guard #available(macOS 14.2, *) else {
            throw ScreenCaptureError.requiresMacOS14
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw ScreenCaptureError.noFrontmostWindow
        }

        // Exclude only Lio's own windows so Claude sees the full desktop including Dock
        let lioWindows = content.windows.filter {
            $0.owningApplication?.applicationName == "Lio"
        }

        let displayScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let filter = SCContentFilter(display: display, excludingWindows: lioWindows)
        let config = SCStreamConfiguration()
        config.width  = Int(display.frame.width  * displayScale)
        config.height = Int(display.frame.height * displayScale)

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config
        )

        // Resize so the longest side ≤ maxLongSide
        let origW = CGFloat(cgImage.width)
        let origH = CGFloat(cgImage.height)
        let scale  = min(1.0, CGFloat(maxLongSide) / max(origW, origH))
        let outW   = max(1, Int(origW * scale))
        let outH   = max(1, Int(origH * scale))

        let resized: CGImage
        if scale < 0.999 {
            let cs = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: nil, width: outW, height: outH,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { throw ScreenCaptureError.captureFailure }
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: outW, height: outH))
            guard let r = ctx.makeImage() else { throw ScreenCaptureError.captureFailure }
            resized = r
        } else {
            resized = cgImage
        }

        let rep = NSBitmapImageRep(cgImage: resized)
        // PNG is lossless — preserves sharp text and UI edges that JPEG blurs,
        // which matters more as resolution decreases.
        guard let pngData = rep.representation(using: .png, properties: [:])
        else { throw ScreenCaptureError.captureFailure }

        // Full display: top-left in Quartz/CGEvent coords = (0, 0) for the primary display.
        // Image Y and Quartz Y both increase downward — no inversion needed.
        let windowOriginTopLeft = CGPoint(x: 0, y: 0)
        let windowSizePoints    = CGSize(width: display.frame.width, height: display.frame.height)

        return CaptureResult(
            base64Image: pngData.base64EncodedString(),
            apiImageSize: CGSize(width: outW, height: outH),
            windowOriginTopLeft: windowOriginTopLeft,
            windowSizePoints: windowSizePoints,
            cgImage: resized
        )
    }
}
