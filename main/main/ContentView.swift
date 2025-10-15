import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var isProcessing = false
    @State private var progressText: String = ""
    @State private var perFrameResults: [(time: CMTime, label: String, confidence: Float)] = []
    @State private var finalLabel: String?
    @State private var finalDetails: String = ""
    @State private var extractionTask: ExtraccionFramesTask?

    // Segundos entre frames a muestrear
    @State private var samplingSeconds: Double = 1.0

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Clasificación de Video con Core ML")
                    .font(.title2)
                    .multilineTextAlignment(.center)

                PhotosPicker(selection: $pickedItem, matching: .videos, photoLibrary: .shared()) {
                    Label("Seleccionar video", systemImage: "video")
                }
                .disabled(isProcessing)

                if let url = videoURL {
                    Text("Video: \(url.lastPathComponent)")
                        .font(.footnote)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack {
                    Text("Muestrear cada")
                    Slider(value: $samplingSeconds, in: 0.25...3.0, step: 0.25)
                    Text(String(format: "%.2f s", samplingSeconds))
                        .monospacedDigit()
                }
                .padding(.horizontal)

                Button {
                    startClassification()
                } label: {
                    Label("Clasificar video", systemImage: "play.circle")
                }
                .disabled(videoURL == nil || isProcessing)

                if isProcessing {
                    ProgressView()
                    Text(progressText).font(.footnote)
                }

                if let finalLabel {
                    VStack(spacing: 8) {
                        Text("Categoría final: \(finalLabel)")
                            .font(.headline)
                        if !finalDetails.isEmpty {
                            Text(finalDetails)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                }

                List {
                    Section("Resultados por frame") {
                        ForEach(Array(perFrameResults.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(String(format: "t=%.2fs", CMTimeGetSeconds(item.time)))
                                    .monospacedDigit()
                                Spacer()
                                Text(item.label)
                                Spacer()
                                Text(String(format: "%.0f%%", item.confidence * 100))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("ContentView")
        }
        .onChange(of: pickedItem) { _, newValue in
            Task { await loadPickedItem(newValue) }
        }
        .onDisappear {
            extractionTask?.cancel()
        }
    }

    private func loadPickedItem(_ item: PhotosPickerItem?) async {
        videoURL = nil
        finalLabel = nil
        finalDetails = ""
        perFrameResults.removeAll()

        guard let item else { return }
        do {
            // Intenta obtener un URL transferible
            if let providerURL = try await item.loadTransferable(type: URL.self) {
                self.videoURL = providerURL
                return
            }
            // Fallback: obtener Data y escribir a un archivo temporal
            if let data = try await item.loadTransferable(type: Data.self) {
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                try data.write(to: tmpURL, options: .atomic)
                self.videoURL = tmpURL
                return
            }
            print("No se pudo obtener URL o Data del video seleccionado.")
        } catch {
            print("Error al cargar el video: \(error)")
        }
    }

    private func startClassification() {
        guard let url = videoURL else { return }

        // Limpiar estado
        isProcessing = true
        progressText = "Preparando..."
        finalLabel = nil
        finalDetails = ""
        perFrameResults.removeAll()

        // Cancelar ejecución previa si existiera
        extractionTask?.cancel()

        // Ejecutar extracción y clasificación cada 'samplingSeconds'
        let task = extraerFrames(
            videoURL: url,
            every: samplingSeconds,
            onFrame: { _ in
                // Aquí podrías contar frames o mostrar previews si quisieras.
            },
            onClassification: { label, confidence, time in
                DispatchQueue.main.async {
                    self.perFrameResults.append((time: time, label: label, confidence: confidence))
                    self.progressText = "Clasificando... \(self.perFrameResults.count) frames"
                }
            },
            onComplete: { [weak self] in
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.progressText = "Completado"
                    self?.computeFinalCategory()
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.progressText = "Error: \(error.localizedDescription)"
                }
            }
        )

        extractionTask = task
    }

    private func computeFinalCategory() {
        guard !perFrameResults.isEmpty else {
            finalLabel = "Sin resultados"
            finalDetails = ""
            return
        }

        // Votación ponderada por confianza
        var tally: [String: Float] = [:]
        for r in perFrameResults {
            tally[r.label, default: 0] += r.confidence
        }

        if let (bestLabel, bestScore) = tally.max(by: { $0.value < $1.value }) {
            finalLabel = bestLabel

            // Info adicional
            let totalScore = tally.values.reduce(0, +)
            let percent = totalScore > 0 ? (bestScore / totalScore) : 0
            let countForBest = perFrameResults.filter { $0.label == bestLabel }.count
            finalDetails = String(
                format: "Frames: %d • Mejor: %d • Confianza acumulada: %.0f%%",
                perFrameResults.count,
                countForBest,
                percent * 100
            )
        } else {
            finalLabel = "Sin categoría"
            finalDetails = ""
        }
    }
}

#Preview {
    ContentView()
}
