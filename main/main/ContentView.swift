import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var dinamicaVM = DinamicaViewModel()
    @State private var estaProcesando: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Somos FutByte")
                .font(.headline)

            Button(action: {
                iniciarEscaneoDeVideo()
            }) {
                Text(estaProcesando ? "Escaneando..." : "Iniciar partido")
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

            if !dinamicaVM.dinamicaActual.isEmpty {
                Text(dinamicaVM.dinamicaActual)
                    .font(.title)
                    .bold()
                    .padding()
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

        // Pasa el ViewModel a Dinamicas
        let dinamicas = Dinamicas()
        dinamicas.viewModel = dinamicaVM

        _ = extraerFrames(
            videoURL: videoURL,
            every: 3.0,
            onFrame: { _ in },
            onClassification: { _, _, _ in },
            onComplete: {
                DispatchQueue.main.async {
                    estaProcesando = false
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
