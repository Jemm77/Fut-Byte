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


enum ImageModelClassifier {
    private static let model: ImageClassifier4_2? = {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly
            print("⚙️ MLModelConfiguration computeUnits set to: \(config.computeUnits)")

            return try ImageClassifier4_2(configuration: config)
        } catch {
            print("⚠️ No se pudo cargar el modelo CoreML: \(error)")
            return nil
        }
    }()

    /// Clasifica un CVPixelBuffer devolviendo la mejor etiqueta.
    static func classify(pixelBuffer: CVPixelBuffer) -> String? {
        guard let model = Self.model else {
            print("⚠️ Modelo CoreML no inicializado")
            return nil
        }

        // Redimensionar a 299x299 si es necesario
        guard let resizedBuffer = resizePixelBuffer(pixelBuffer, width: 299, height: 299) else {
            print("⚠️ No se pudo redimensionar el frame a 299x299")
            return nil
        }

        print("ℹ️ Input pixelBuffer size: \(CVPixelBufferGetWidth(resizedBuffer))x\(CVPixelBufferGetHeight(resizedBuffer)), format: \(CVPixelBufferGetPixelFormatType(resizedBuffer))")

        do {
            // Si existe el struct Input generado automáticamente, se puede usar:
            let input = ImageClassifier4_2Input(image: resizedBuffer)
            let prediction = try model.prediction(input: input)
            let label = prediction.target

            // Llama a la asignación de dinámica
            let dinamicas = Dinamicas()
            dinamicas.asignarDinamica(para: label)

            return label
        } catch {
            print("⚠️ Error clasificando frame: \(error)")
            return nil
        }
    }

    /// Clasifica un CGImage convirtiéndolo a CVPixelBuffer primero.
    static func classify(cgImage: CGImage) -> String? {
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
                                  kCVPixelFormatType_32BGRA,
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
        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let scaleX = CGFloat(width) / CGFloat(sourceWidth)
        let scaleY = CGFloat(height) / CGFloat(sourceHeight)
        let scale = max(scaleX, scaleY) // Aspect fill

        let scaledWidth = CGFloat(sourceWidth) * scale
        let scaledHeight = CGFloat(sourceHeight) * scale

        let xOffset = (CGFloat(width) - scaledWidth) / 2.0
        let yOffset = (CGFloat(height) - scaledHeight) / 2.0

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))

        let context = CIContext()
        var resizedPixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attrs,
                                         &resizedPixelBuffer)
        guard status == kCVReturnSuccess, let output = resizedPixelBuffer else {
            return nil
        }

        context.render(ciImage,
                       to: output,
                       bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        return output
    }
}

