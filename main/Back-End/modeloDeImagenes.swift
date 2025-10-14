//
//  modeloDeImagenes.swift
//  main
//
//  Created by CETYS Universidad  on 14/10/25.
//

import AVFoundation
import CoreML
import Vision
import UIKit


let clasificadorDeJuagdas = try? ImageClassifier4_2(configuration: .init())

enum ImageModelClassifier {
    /// Clasifica un `CVPixelBuffer` devolviendo la mejor etiqueta y su confianza.
    static func classify(pixelBuffer: CVPixelBuffer) -> (label: String, confidence: Float)? {
        guard let model = clasificadorDeJuagdas else { return nil }
        // Intenta usar la entrada que mejor se adapte a tu modelo generado.
        // Muchos modelos generados aceptan `CVPixelBuffer` directamente.
        do {
            if let prediction = try? model.prediction(image: pixelBuffer) {
                // Ajusta el acceso a `classLabel`/`classLabelProbs` según tu modelo generado.
                let label = prediction.target
                let confidence = prediction.targetProbability[label] ?? 0
                return (label, Float(confidence))
            }

            // Alternativa: si tu modelo espera MLMultiArray/otros tipos, adapta aquí.
            return nil
        }
    }

    /// Clasifica un `CGImage` convirtiéndolo a `CVPixelBuffer` primero.
    static func classify(cgImage: CGImage) -> (label: String, confidence: Float)? {
        guard let pb = Self.pixelBuffer(from: cgImage) else { return nil }
        return classify(pixelBuffer: pb)
    }

    /// Versión async que permite ejecutar en background fácilmente.
    static func classifyAsync(pixelBuffer: CVPixelBuffer) async -> (label: String, confidence: Float)? {
        // Evitar capturar CVPixelBuffer en un cierre @Sendable de GCD/continuation.
        // Usamos Task, cuyo closure no es @Sendable por defecto en main actor.
        let pb = pixelBuffer // copiar referencia local
        return await Task(priority: .userInitiated) { () -> (label: String, confidence: Float)? in
            return classify(pixelBuffer: pb)
        }.value
    }
}

// MARK: - Utilidades de conversión
private extension ImageModelClassifier {
    static func pixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
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
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pb
    }
}

