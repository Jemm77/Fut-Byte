import AVFoundation
import Foundation
import Combine //añadio esta libreria,que @Published necesita

//Uso de chat-GPT5 para correciones prompt:"Hola, Chat, me gustaria que me ayudaras a corregir y ayudarme a entender los errores al inicio de la clase Grabadora como tambien en la funcion solicitarPermiso(), porfavor "

final class Grabadora: NSObject, AVAudioRecorderDelegate, ObservableObject {
    private var grabadora: AVAudioRecorder?
    @Published var permisoConcedido: Bool = false
    @Published var estaGrabando: Bool = false

    // Opcional: consulta el estado actual del permiso sin disparar el prompt del sistema.
    func actualizarEstadoPermiso() {
        let permiso = AVAudioSession.sharedInstance().recordPermission
        DispatchQueue.main.async {
            self.permisoConcedido = (permiso == .granted)
        }
    }

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
        guard permisoConcedido else {
            print("No se puede grabar: permiso de micrófono no concedido.")
            return
        }

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
