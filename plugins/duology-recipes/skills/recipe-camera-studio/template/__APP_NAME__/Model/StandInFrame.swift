import CoreGraphics
import Foundation
import ImageIO

/// The stand-in camera's picture: colour bars, a corner tag and a dot that moves, so a frame
/// shows it is live, which way up it is and whether it is mirrored. The simulator has no camera
/// (measured in `duo-camera`); with this, the preview, the shutter, the timer, recording and the
/// gallery all work there. The SwiftUI preview and the saved photos and videos draw the same
/// shapes, from `swatches(in:time:)`.
nonisolated enum StandInFrame {
    nonisolated struct Swatch: Equatable, Sendable {
        let rect: CGRect
        let red: Double
        let green: Double
        let blue: Double
    }

    /// 75 % colour bars, left to right. Mirrored, they run the other way.
    static let barColors: [(Double, Double, Double)] = [
        (0.75, 0.75, 0.75), (0.75, 0.75, 0), (0, 0.75, 0.75), (0, 0.75, 0), (0.75, 0, 0.75), (0.75, 0, 0), (0, 0, 0.75),
    ]
    /// One trip of the dot across the frame, in seconds.
    static let period: Double = 2

    /// What to draw, in order, in a frame of `size` with the origin at the top left.
    static func swatches(in size: CGSize, time: Double) -> [Swatch] {
        guard size.width > 0, size.height > 0 else { return [] }
        let barHeight = (size.height * 0.7).rounded()
        let barWidth = size.width / CGFloat(barColors.count)
        var result = barColors.enumerated().map { index, colour in
            Swatch(rect: CGRect(x: CGFloat(index) * barWidth, y: 0, width: barWidth, height: barHeight),
                   red: colour.0, green: colour.1, blue: colour.2)
        }
        // The band below the bars, and the dot moving across it.
        let band = CGRect(x: 0, y: barHeight, width: size.width, height: size.height - barHeight)
        result.append(Swatch(rect: band, red: 0.08, green: 0.08, blue: 0.1))
        let side = min(band.height * 0.6, size.width / 8)
        let phase = (time.truncatingRemainder(dividingBy: period) + period).truncatingRemainder(dividingBy: period) / period
        let x = side / 2 + (size.width - 2 * side) * phase
        result.append(Swatch(rect: CGRect(x: x, y: band.midY - side / 2, width: side, height: side), red: 1, green: 1, blue: 1))
        // A white tag in the top-left corner: the frame's "up" and "left" at a glance.
        let tag = min(size.width, size.height) * 0.08
        result.append(Swatch(rect: CGRect(x: tag / 2, y: tag / 2, width: tag, height: tag), red: 1, green: 1, blue: 1))
        return result
    }

    /// The largest rect of `content`'s shape that fits in `space`, centred: how a preview with
    /// `.resizeAspect` gravity shows the camera's frame.
    static func fitted(_ content: CGSize, in space: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0, space.width > 0, space.height > 0 else { return .zero }
        let scale = min(space.width / content.width, space.height / content.height)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        return CGRect(x: (space.width - size.width) / 2, y: (space.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// The frame as an image, for a stand-in photo or one frame of a stand-in video.
    static func render(size: CGSize, time: Double) -> CGImage? {
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        // Core Graphics puts the origin at the bottom left; the swatches use the top left.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        for swatch in swatches(in: size, time: time) {
            context.setFillColor(red: swatch.red, green: swatch.green, blue: swatch.blue, alpha: 1)
            context.fill(swatch.rect)
        }
        return context.makeImage()
    }

    /// JPEG data, no alpha, for a saved photo or a video's poster.
    static func jpeg(_ image: CGImage, quality: Double = 0.85) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
