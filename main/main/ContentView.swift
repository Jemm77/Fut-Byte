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

            Spacer()
        }
        .padding()
        // Si añadiste `actualizarEstadoPermiso()` en Grabadora, puedes sincronizar el estado al aparecer:
        // .onAppear {
        //     grabadora.actualizarEstadoPermiso()
        // }
    }
}

#Preview {
    ContentView()
}
