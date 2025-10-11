//
//  ContentView.swift
//  main
//
//  Created by CETYS Universidad  on 06/10/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct ContentView: View {
    @StateObject private var grabadora = Grabadora()
    @State private var framesExtraidos: [UIImage] = []
    @State private var videoURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            Text("Somos futbyte, a ver si ya jala el GitHub")
                .font(.headline)

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

            Divider()

            // Selección de video de ejemplo desde el bundle o sandbox
            Button("Usar video de ejemplo del bundle") {
                if let sample = Bundle.main.url(forResource: "SampleVideo", withExtension: "mp4") {
                    videoURL = sample
                } else {
                    print("No se encontró SampleVideo.mp4 en el bundle.")
                }
            }

            Button("Extraer frames cada 5s") {
                guard let url = videoURL else {
                    print("Asigna primero un videoURL (por ejemplo, con el botón de ejemplo).")
                    return
                }
                framesExtraidos = extraerFrames(videoURL: url, every: 5)
                print("Total frames extraídos: \(framesExtraidos.count)")
            }

            Text("Frames extraídos: \(framesExtraidos.count)")
                .font(.subheadline)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack {
                    ForEach(Array(framesExtraidos.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
