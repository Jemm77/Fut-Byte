import SwiftUI

// Aqui codificaremos la logica de nuestro sistema de recompensas es decir, que el modelo de sonido que vamos a programar mande una señal positiva y que se marque como completada una tarea

public protocol RewardSystem {
    func didCompleteTask() -> Bool
}

