import SwiftUI

// Aqui codificaremos la logica de nuestro sistema de recompensas es decir, que el modelo de sonido que vamos a programar mande una señal positiva y que se marque como completada una tarea

public protocol SistemaDeRecompensas {
    func didCompleteTask() -> Bool
}

/// Implementación por defecto del sistema de recompensas
public struct DefaultSistemaDeRecompensas: SistemaDeRecompensas {
    // Estado interno simple para ejemplo; puedes adaptarlo a tu lógica real
    private var hasCompletedTask: Bool = false

    public init() {}

    /// Marca la tarea como completada y devuelve true para indicar éxito
    public func didCompleteTask() -> Bool {
        // Aquí podrías: reproducir un sonido, enviar haptic feedback, guardar estado, etc.
        return true
    }
}
