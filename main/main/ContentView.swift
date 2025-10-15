import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var ultimaCategoria: String = ""
    @State private var ultimaConfianza: Float = 0
    @State private var estaProcesando: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Somos FutByte")
                .font(.headline)

            Button(action: {
                iniciarEscaneoDeVideo()
            }) {
                Text(estaProcesando ? "Escaneando..." : "Escanear video")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(estaProcesando)

            if estaProcesando {
                ProgressView()
                Text("Procesando video...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !ultimaCategoria.isEmpty {
                Text("Categoría: \(ultimaCategoria)")
                    .font(.title3)
                    .bold()
                Text(String(format: "Confianza: %.2f", ultimaConfianza))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func iniciarEscaneoDeVideo() {
        let nombre = "partido"
        let ext = "mp4"

        guard let videoURL = Bundle.main.url(forResource: nombre, withExtension: ext) else {
            print("❌ No se encontró el video en el bundle.")
            return
        }

        estaProcesando = true
        ultimaCategoria = ""
        ultimaConfianza = 0

        _ = extraerFrames(
            videoURL: videoURL,
            every: 3.0,
            onFrame: { _ in },
            onClassification: { label, confidence, _ in
                DispatchQueue.main.async {
                    ultimaCategoria = label
                    ultimaConfianza = confidence
                }
            },
            onComplete: {
                DispatchQueue.main.async {
                    estaProcesando = false
                    print("✅ Clasificación completada")
                }
            },
            onError: { error in
                print("Error: \(error)")
                DispatchQueue.main.async {
                    estaProcesando = false
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
