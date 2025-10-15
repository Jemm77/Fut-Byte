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

// Carga del modelo CoreML generado automáticamente
let clasificadorDeJugadas = try? ImageClassifier4_2(configuration: MLModelConfiguration())

enum ImageModelClassifier {
    /// Clasifica un CVPixelBuffer devolviendo la mejor etiqueta y su confianza.
    static func classify(pixelBuffer: CVPixelBuffer) -> (label: String, confidence: Float)? {
        guard let model = clasificadorDeJugadas else {
            print("⚠️ No se pudo cargar el modelo CoreML")
            return nil
        }

        // Redimensionar a 299x299 si es necesario
        guard let resizedBuffer = resizePixelBuffer(pixelBuffer, width: 299, height: 299) else {
            print("⚠️ No se pudo redimensionar el frame a 299x299")
            return nil
        }

        do {
            // Usa las propiedades correctas del modelo (ver .mlmodel)
            let prediction = try model.prediction(image: resizedBuffer)
            let label = prediction.target
            let confidence = Float(prediction.targetProbability[label] ?? 0)
            return (label, confidence)
        } catch {
            print("⚠️ Error clasificando frame: \(error)")
            return nil
        }
    }

    /// Clasifica un CGImage convirtiéndolo a CVPixelBuffer primero.
    static func classify(cgImage: CGImage) -> (label: String, confidence: Float)? {
        guard let pb = Self.pixelBuffer(from: cgImage) else { return nil }
        return classify(pixelBuffer: pb)
    }
}

// MARK: - Utilidades
private extension ImageModelClassifier {
    /// Convierte CGImage a CVPixelBuffer (BGRA)
    static func pixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
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

    /// Redimensiona un CVPixelBuffer a otro tamaño (para modelos que esperan 299x299)
    static func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaleX = CGFloat(width) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let scaleY = CGFloat(height) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        var resized: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary

        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &resized)
        guard let output = resized else { return nil }

        context.render(ciImage, to: output)
        return output
    }
}
