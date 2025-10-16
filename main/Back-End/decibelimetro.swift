//
//  decibelimetro.swift
//  main
//
//  Created by CETYS Universidad  on 11/10/25.
//

import AVFoundation

public class Decibelimetro {
    private let engine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var maxDecibeles: Float = 0
    private var timer: Timer?

    public init() {}

    // Medir decibeles durante 'duracion' segundos y llamar al completion con el máximo alcanzado y si se logró la meta
    public func medirDecibelesObjetivo(objetivo: Float, duracion: TimeInterval = 15.0, completion: @escaping (Float, Bool) -> Void) {
        inputNode = engine.inputNode
        maxDecibeles = 0

        let format = inputNode!.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            let level = self.calculateSPL(from: buffer)
            if level > self.maxDecibeles {
                self.maxDecibeles = level
            }
        }

        do {
            try engine.start()
        } catch {
            completion(0, false)
            return
        }

        // Detener después de 'duracion' segundos
        timer = Timer.scheduledTimer(withTimeInterval: duracion, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.inputNode?.removeTap(onBus: 0)
            self.engine.stop()
            let metaAlcanzada = self.maxDecibeles >= objetivo
            completion(self.maxDecibeles, metaAlcanzada)
        }
    }

    // Ejemplo simple de cálculo de SPL (Sound Pressure Level)
    private func calculateSPL(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let spl = 20 * log10(rms)
        return spl.isFinite ? spl + 100 : 0 // Ajuste para valores positivos
    }
}
