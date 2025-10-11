import AVFoundation
import UIKit
import CoreVideo

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
    onComplete: @escaping () -> Void,
    onError: @escaping (Error) -> Void
) -> ExtraccionFramesTask {

    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    // Opcional: si quieres mayor rendimiento y no te importa una ligera interpolación
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    // Construir la lista de tiempos a muestrear
    let durationSeconds = CMTimeGetSeconds(asset(.duration))
    var times = [NSValue]()
    var current = 0.0
    while current < durationSeconds {
        let time = CMTime(seconds: current, preferredTimescale: 600)
        times.append(NSValue(time: time))
        current += seconds
    }
    // Asegurar el último tiempo exacto si cae justo al final
    if let last = times.last?.timeValue, last < asset(.duration) {
        // no-op
    }

    // Estado de cancelación
    var cancelled = false

    // Handler de cancelación: cancela tareas pendientes del generator
    let task = ExtraccionFramesTask { [weak generator] in
        cancelled = true
        generator?.cancelAllCGImageGeneration()
    }

    // Proceso asíncrono de generación de imágenes
    generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, actualTime, result, error in
        // Si cancelado, no hacer nada más
        if cancelled { return }

        switch result {
        case .succeeded:
            if let cgImage = cgImage {
                // Convertir a CVPixelBuffer y entregar
                if let pb = pixelBuffer(from: cgImage) {
                    onFrame(pb)
                } else {
                    // Si falla la conversión, lo tratamos como error recuperable
                    // Puedes optar por ignorar este frame y continuar.
                    // Aquí seguimos ignorando este frame y continuamos sin cortar el flujo.
                }
            }

        case .failed:
            // Informar error y no continuar
            let e = error ?? NSError(domain: "extraerFrames", code: -1, userInfo: [NSLocalizedDescriptionKey: "Fallo al generar CGImage en tiempo \(actualTime)"])
            onError(e)
            // Cancelar el resto para no seguir llamando callbacks
            task.cancel()

        case .cancelled:
            // No hacemos nada más; el usuario canceló.
            break

        @unknown default:
            break
        }

       
    }


    generator.cancelAllCGImageGeneration() // cancelar la anterior por seguridad (no debería haber empezado)
    let total = times.count
    if total == 0 {
        // No hay frames que extraer; completamos inmediatamente
        DispatchQueue.main.async {
            onComplete()
        }
        return task
    }

    var remaining = total
    generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, actualTime, result, error in
        if cancelled { return }

        switch result {
        case .succeeded:
            if let cgImage = cgImage, let pb = pixelBuffer(from: cgImage) {
                onFrame(pb)
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
