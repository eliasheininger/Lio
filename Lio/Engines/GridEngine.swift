import AppKit
import CoreGraphics
import Foundation

/// Geometry for a grid laid over the API image.
struct GridConfig {
    let columns: Int
    let rows: Int
    let imageSize: CGSize

    var cellWidth:  CGFloat { imageSize.width  / CGFloat(columns) }
    var cellHeight: CGFloat { imageSize.height / CGFloat(rows) }
}

/// Overlays a labeled spreadsheet-style grid (A–Z columns, 1–N rows) on screenshots
/// so Claude can reference cells by label instead of estimating pixel coordinates.
final class GridEngine {
    let columns = 26   // A–Z
    let rows    = 16   // 1–16

    // MARK: - Label parsing

    /// Parses "D5" → zero-based (col: 3, row: 4). Returns nil for invalid input.
    func parseCell(_ label: String) -> (col: Int, row: Int)? {
        let s = label.uppercased()
        guard !s.isEmpty else { return nil }

        // Split into leading letters and trailing digits
        let letters = s.prefix(while: { $0.isLetter })
        let digits  = s.dropFirst(letters.count)

        guard letters.count == 1,
              let colChar = letters.first,
              let colIdx  = colChar.asciiValue.map({ Int($0) - Int(Character("A").asciiValue!) }),
              colIdx >= 0, colIdx < columns,
              let rowNum = Int(digits),
              rowNum >= 1, rowNum <= rows
        else { return nil }

        return (col: colIdx, row: rowNum - 1)
    }

    // MARK: - Coordinate math

    /// Center of a grid cell in API image pixel space (top-left origin).
    func cellCenterInImage(_ label: String, config: GridConfig) -> CGPoint? {
        guard let (col, row) = parseCell(label) else { return nil }
        return CGPoint(
            x: (CGFloat(col) + 0.5) * config.cellWidth,
            y: (CGFloat(row) + 0.5) * config.cellHeight
        )
    }

    /// Center of a grid cell in Quartz/CGEvent screen coordinates.
    func cellCenterInScreen(_ label: String, capture: CaptureResult) -> CGPoint? {
        let config = GridConfig(columns: columns, rows: rows, imageSize: capture.apiImageSize)
        guard let imagePoint = cellCenterInImage(label, config: config) else { return nil }

        let scaleX = capture.windowSizePoints.width  / capture.apiImageSize.width
        let scaleY = capture.windowSizePoints.height / capture.apiImageSize.height

        return CGPoint(
            x: capture.windowOriginTopLeft.x + imagePoint.x * scaleX,
            y: capture.windowOriginTopLeft.y + imagePoint.y * scaleY
        )
    }

    // MARK: - Annotation

    /// Draws a semi-transparent labeled grid onto `image`. Returns a new CGImage.
    func annotate(_ image: CGImage, config: GridConfig) -> CGImage? {
        let w = image.width
        let h = image.height

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        // Draw original image
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        // CGContext has bottom-left origin; flip for standard top-left drawing
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)

        let cellW = CGFloat(w) / CGFloat(config.columns)
        let cellH = CGFloat(h) / CGFloat(config.rows)

        // Grid lines
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
        ctx.setLineWidth(0.5)

        for col in 1..<config.columns {
            let x = CGFloat(col) * cellW
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: CGFloat(h)))
        }
        for row in 1..<config.rows {
            let y = CGFloat(row) * cellH
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: CGFloat(w), y: y))
        }
        ctx.strokePath()

        // Cell labels
        let fontSize: CGFloat = max(8, min(cellW * 0.28, 11))
        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let chipPadX: CGFloat = 2
        let chipPadY: CGFloat = 1.5

        for col in 0..<config.columns {
            for row in 0..<config.rows {
                let colLetter = String(UnicodeScalar(UInt8(col) + UInt8(Character("A").asciiValue!)))
                let label = "\(colLetter)\(row + 1)"

                let attrs: [CFString: Any] = [
                    kCTFontAttributeName: font,
                    kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                ]
                let attrStr = CFAttributedStringCreate(nil, label as CFString, attrs as CFDictionary)!
                let line = CTLineCreateWithAttributedString(attrStr)
                let bounds = CTLineGetImageBounds(line, ctx)

                let cellX = CGFloat(col) * cellW
                let cellY = CGFloat(row) * cellH
                let textX = cellX + chipPadX + chipPadX
                let textY = cellY + chipPadY + chipPadY

                // Dark chip behind label
                let chipRect = CGRect(
                    x: cellX + chipPadX,
                    y: cellY + chipPadY,
                    width: bounds.width + chipPadX * 2,
                    height: bounds.height + chipPadY * 2
                )
                let chipPath = CGPath(roundedRect: chipRect, cornerWidth: 1, cornerHeight: 1, transform: nil)
                ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
                ctx.addPath(chipPath)
                ctx.fillPath()

                // Label text
                ctx.textPosition = CGPoint(x: textX, y: textY)
                CTLineDraw(line, ctx)
            }
        }

        ctx.restoreGState()
        return ctx.makeImage()
    }

    /// Annotates the capture's screenshot and returns a new base64 JPEG string.
    /// Uses `capture.cgImage` if available to skip JPEG decode; falls back to decoding `base64JPEG`.
    func annotatedBase64JPEG(capture: CaptureResult, quality: CGFloat = 0.85) -> String? {
        let source: CGImage
        if let img = capture.cgImage {
            source = img
        } else {
            guard let data = Data(base64Encoded: capture.base64JPEG),
                  let provider = CGDataProvider(data: data as CFData),
                  let decoded = CGImage(
                    jpegDataProviderSource: provider, decode: nil,
                    shouldInterpolate: true, intent: .defaultIntent
                  )
            else { return nil }
            source = decoded
        }

        let config = GridConfig(columns: columns, rows: rows, imageSize: capture.apiImageSize)
        guard let annotated = annotate(source, config: config) else { return nil }

        let rep = NSBitmapImageRep(cgImage: annotated)
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        else { return nil }
        return jpeg.base64EncodedString()
    }
}
