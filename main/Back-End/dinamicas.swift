import Foundation
// Importa el archivo del modelo de letra de canción
import Playgrounds
import FoundationModels

class Dinamicas {
    var viewModel: DinamicaViewModel?
    var sistemaDeRecompensas: SistemaDeRecompensas? // Usa el tipo real del backend

    func asignarDinamica(para categoria: String) {
        var dinamica = ""
        switch categoria {
        case "TiroDeEsquina":
            dinamica = "¡Aplaudir!"
        case "SaqueDeManos":
            dinamica = "¡Levantar las manos!"
        case "GritoDeGol":
            dinamica = "¡Gritar!"
        case "Ceremonia":
            // Nota: si tu seleccionCancion del backend requiere parámetros, actualiza esta llamada, por ejemplo:
            // let seleccion = seleccionCancion(para: "Ceremonia")
            let seleccion = seleccionCancion()
            let nombreCancion = seleccion.cancion
            let letra = obtenerLetraDeCancion(nombre: nombreCancion)
            dinamica = "¡Cantar una canción!\n\nCanción: \(nombreCancion)\nLetra:\n\(letra)"
        case "Penal":
            // Motivar a gritar y medir decibeles en tiempo real durante 15 segundos
            dinamica = "¡Es penal!\n\n¡Todos a gritar y llegar a 100 dB!\nMidiendo decibeles..."
            viewModel?.mostrarDinamica(dinamica)

            let decibelimetro = Decibelimetro()
            let objetivo: Float = 100
            decibelimetro.medirDecibelesObjetivo(objetivo: objetivo, duracion: 15.0) { [weak self] decibeles, metaAlcanzada in
                guard let self = self else { return }
                var recompensaMensaje = ""
                if metaAlcanzada {
                    if let rewards = self.sistemaDeRecompensas {
                        if rewards.didCompleteTask() {
                            recompensaMensaje = "\n¡Meta alcanzada! +10 puntos de recompensa."
                        } else {
                            recompensaMensaje = "\n¡Meta alcanzada!"
                        }
                    } else {
                        recompensaMensaje = "\n¡Meta alcanzada!"
                    }
                } else {
                    recompensaMensaje = "\nNo se alcanzó la meta."
                }
                let resultado = String(format: "¡Es penal!\n\n¡Todos a gritar y llegar a %.0f dB!\nDecibeles logrados: %.1f dB%@", objetivo, decibeles, recompensaMensaje)
                self.viewModel?.mostrarDinamica(resultado)
            }
        case "juegoContinuo":
            return // No hacer nada
        default:
            dinamica = ""
        }
        viewModel?.mostrarDinamica(dinamica)
    }

    // Simulación de función para obtener la letra de la canción usando Foundation Model
    private func obtenerLetraDeCancion(nombre: String) -> String {
        #if canImport(FoundationModels)
        return obtenerLetraCancion(nombre: nombre)
        #else
        return "[Letra no disponible: agrega FoundationModels o tu backend para obtener la letra de \(nombre).]"
        #endif
    }
    
    // Fallback local overload para evitar el error de parámetros faltantes si la implementación del backend
    // no ofrece una versión sin parámetros. Sustituye por tu llamada real si tu firma requiere argumentos.
    private struct SeleccionCancionResult { let cancion: String }
    private func seleccionCancion() -> SeleccionCancionResult {
        // Ajusta esta lógica para alinearla con tu backend (por ejemplo, pasando una categoría)
        return SeleccionCancionResult(cancion: "We Will Rock You")
    }
}

