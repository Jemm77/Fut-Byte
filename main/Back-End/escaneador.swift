import AVFoundation
import UIKit
import CoreVideo
import CoreML

public final class ExtraccionFramesTask {
    private let cancelClosure: () -> Void
    private var isCancelled = false

    init(cancelClosure: @escaping () -> Void) {
        self.cancelClosure = cancelClosure
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        cancelClosure()
    }
}

/// Convierte CGImage a CVPixelBuffer (BGRA)
private func pixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
    let width = cgImage.width
    let height = cgImage.height

    var pixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]

    guard CVPixelBufferCreate(kCFAllocatorDefault,
                              width,
                              height,
                              kCVPixelFormatType_32ARGB,
                              attrs as CFDictionary,
                              &pixelBuffer) == kCVReturnSuccess,
          let pb = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(pb, [])
    defer { CVPixelBufferUnlockBaseAddress(pb, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pb) else { return nil }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: baseAddress,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                              CGBitmapInfo.byteOrder32Little.rawValue)
    else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pb
}

/// Extrae frames del video, los pasa por el modelo y reporta resultados.
@discardableResult
func extraerFrames(
    videoURL: URL,
    every seconds: Double,
    onFrame: @escaping (CVPixelBuffer) -> Void,
    onClassification: @escaping (_ label: String, _ confidence: Float, _ time: CMTime) -> Void,
    onComplete: @escaping () -> Void,
    onError: @escaping (Error) -> Void
) -> ExtraccionFramesTask {

    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    let duration = asset.duration
    let durationSeconds = CMTimeGetSeconds(duration)

    var times = [NSValue]()
    var current = 0.0
    while current < durationSeconds {
        let time = CMTime(seconds: current, preferredTimescale: 600)
        times.append(NSValue(time: time))
        current += seconds
    }

    var cancelled = false

    let task = ExtraccionFramesTask { [weak generator] in
        cancelled = true
        generator?.cancelAllCGImageGeneration()
    }

    if times.isEmpty {
        DispatchQueue.main.async { onComplete() }
        return task
    }

    DispatchQueue.global(qos: .userInitiated).async {
        generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, actualTime, result, error in
            if cancelled { return }

            switch result {
            case .succeeded:
                if let cgImage = cgImage, let pb = pixelBuffer(from: cgImage) {
                    onFrame(pb)
                    if let res = ImageModelClassifier.classify(pixelBuffer: pb) {
                        onClassification(res.label, res.confidence, actualTime)
                    }
                }
            case .failed:
                onError(error ?? NSError(domain: "extraerFrames", code: -1,
                                         userInfo: [NSLocalizedDescriptionKey: "Fallo en \(actualTime)"]))
                task.cancel()
            case .cancelled:
                return
            @unknown default:
                return
            }
        }

        DispatchQueue.main.async { onComplete() }
    }

    return task
}
