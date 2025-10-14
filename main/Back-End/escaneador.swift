import AVFoundation
import UIKit
import CoreVideo
import CoreML

// correccion con IA Chat-GPT5 asistente de xCode: Prompt utilizado, ¨Que correciones deberia hacerle a esta parte del codigo si quiero, no guardar las imagenes, correrla por detras en la aplicacion y quiero usarla despues en un modelo de ML¨

/// Manejador de extracción que permite cancelar el proceso.
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

/// Convierte un CGImage a CVPixelBuffer con un formato apropiado para ML (BGRA).
private func pixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
    let width = cgImage.width
    let height = cgImage.height

    var pixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
    ]

    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     width,
                                     height,
                                     kCVPixelFormatType_32BGRA,
                                     attrs as CFDictionary,
                                     &pixelBuffer)
    guard status == kCVReturnSuccess, let pb = pixelBuffer else {
        return nil
    }

    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pb) else { return nil }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: baseAddress,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
        return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return pb
}

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

    // Cargar duración con la nueva API (iOS 16+). Como esta función es sync,
    // puenteamos a async con un semáforo.
    var duration: CMTime = .zero
    let sem = DispatchSemaphore(value: 0)
    Task {
        if let d = try? await asset.load(.duration) {
            duration = d
        } else {
            duration = asset.duration // fallback (podría mostrar warning en iOS 16+, pero solo si se usa)
        }
        sem.signal()
    }
    sem.wait()

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

    var remaining = times.count
    if remaining == 0 {
        DispatchQueue.main.async { onComplete() }
        return task
    }

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
            let e = error ?? NSError(domain: "extraerFrames", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fallo al generar CGImage en tiempo \(actualTime)"])
            onError(e)
            task.cancel()
            return
        case .cancelled:
            return
        @unknown default:
            return
        }

        remaining -= 1
        if remaining == 0 && !cancelled {
            onComplete()
        }
    }

    return task
}
