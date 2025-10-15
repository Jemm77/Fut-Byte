//
//  ContentView.swift
//  main
//
//  Created by CETYS Universidad  on 06/10/25.
//

import SwiftUI
import AVFoundation

//Chat-GPT hizo un desastre aqui, vamos a ponerlo a corregir prompt"En este caso se estan usando funciones de una seccion del BackEnd mas especificamente de escaneador, las cuales quiero que funcionen por detras, porfavor corrigelas"

struct ContentView: View {
    @StateObject private var grabadora = Grabadora()
    @State private var ultimaCategoria: String = ""
    @State private var ultimaConfianza: Float = 0
    @State private var estaProcesando: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Somos futbyte, a ver si ya jala el GitHub")
                .font(.headline)

            Button("Probar video (bundle)") {
                probarVideoDesdeBundle()
            }

            VStack(spacing: 8) {
                if estaProcesando {
                    ProgressView().progressViewStyle(.circular)
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
            }

            // Permisos de micrófono
            HStack {
                Button("Solicitar permiso micrófono") {
                    grabadora.solicitarPermiso()
                }
                Text(grabadora.permisoConcedido ? "Permiso OK" : "Sin permiso")
                    .foregroundStyle(grabadora.permisoConcedido ? .green : .red)
            }

            // Controles de grabación
            HStack {
                Button(grabadora.estaGrabando ? "Grabando..." : "Iniciar grabación") {
                    grabadora.inicioDeGrabacion()
                }
                .disabled(grabadora.estaGrabando == true || grabadora.permisoConcedido == false)

                Button("Detener") {
                    grabadora.detenerGrabacion()
                }
                .disabled(grabadora.estaGrabando == false)
            }

            Spacer()
        }
        .padding()
    }

    private func probarVideoDesdeBundle() {
        guard let url = Bundle.main.url(forResource: "WhatsApp Video 2025-10-14 at 5.13.04 PM", withExtension: "mp4", subdirectory: "video") else {
            print("No se encontró el video en el bundle dentro del subdirectorio 'video'. Revisa que la carpeta sea una folder reference (azul) o que el archivo esté en Copy Bundle Resources y con Target Membership activo.")
            return
        }

        DispatchQueue.main.async {
            self.estaProcesando = true
            self.ultimaCategoria = ""
            self.ultimaConfianza = 0
        }

        _ = extraerFrames(
            videoURL: url,
            every: 3.0,
            onFrame: { _ in },
            onClassification: { label, confidence, time in
                DispatchQueue.main.async {
                    self.ultimaCategoria = label
                    self.ultimaConfianza = confidence
                }
            },
            onComplete: {
                DispatchQueue.main.async {
                    self.estaProcesando = false
                }
                print("Clasificación terminada")
            },
            onError: { error in
                print("Error: \(error)")
            }
        )
    }
}

#Preview {
    ContentView()
}
