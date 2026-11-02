import AVFoundation
import CoreVideo

/// Writes a real movie of the stand-in camera's picture, so recording, the gallery and playback
/// can be tried in the simulator. H.264 at 640 × 480, 15 frames a second, no sound.
actor StandInRecorder {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var loop: Task<Void, Never>?
    private var frames: Int64 = 0

    func start(to url: URL) throws {
        let size = AppFacts.standInVideoSize
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CaptureError.notConfigured }
        writer.startSession(atSourceTime: .zero)
        (self.writer, self.input, self.adaptor, frames) = (writer, input, adaptor, 0)
        let rate = AppFacts.standInFrameRate
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.appendFrame(rate: rate)
                try? await Task.sleep(for: .milliseconds(1000 / Int(rate)))
            }
        }
    }

    private func appendFrame(rate: Int32) {
        guard let input, let adaptor, input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }
        let time = Double(frames) / Double(rate)
        draw(time: time, into: buffer)
        if adaptor.append(buffer, withPresentationTime: CMTime(value: frames, timescale: rate)) {
            frames += 1
        }
    }

    private func draw(time: Double, into buffer: CVPixelBuffer) {
        guard let image = StandInFrame.render(size: AppFacts.standInVideoSize, time: time) else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(image, in: CGRect(origin: .zero, size: AppFacts.standInVideoSize))
    }

    /// Stops and finishes the file. Returns its length in seconds.
    func stop() async throws -> Double {
        loop?.cancel()
        loop = nil
        guard let writer, let input else { throw CaptureError.notRecording }
        input.markAsFinished()
        await writer.finishWriting()
        let seconds = Double(frames) / Double(AppFacts.standInFrameRate)
        (self.writer, self.input, self.adaptor) = (nil, nil, nil)
        if writer.status == .failed { throw writer.error ?? CaptureError.notRecording }
        return seconds
    }
}

/// A still from a movie, for the gallery's grid.
enum Poster {
    static func jpeg(fromMovieAt url: URL) async -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let (image, _) = try? await generator.image(at: .zero) else { return nil }
        return StandInFrame.jpeg(image)
    }
}
