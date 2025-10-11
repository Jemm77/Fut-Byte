import AVFoundation
import Foundation

final class Grabadora: NSObject, AVAudioRecorderDelegate, ObservableObject {
    private var grabadora: AVAudioRecorder?
    @Published var permisoConcedido: Bool = false
    @Published var estaGrabando: Bool = false

    func solicitarPermiso() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permisoConcedido = granted
                if granted {
                    print("Permiso concedido")
                } else {
                    print("Permiso denegado")
                }
            }
        }
    }

    func inicioDeGrabacion(duration: TimeInterval? = nil) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            grabadora = try AVAudioRecorder(url: url, settings: settings)
            grabadora?.delegate = self

            if let duration {
                grabadora?.record(forDuration: duration)
            } else {
                grabadora?.record()
            }
            estaGrabando = true
        } catch {
            print("Error al configurar la grabación: \(error)")
            estaGrabando = false
        }
    }

    func detenerGrabacion() {
        grabadora?.stop()
        estaGrabando = false
    }

    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.estaGrabando = false
        }
        print("Grabación finalizada. Éxito: \(flag)")
    }

    var urlGrabacion: URL? {
        grabadora?.url
    }
}
