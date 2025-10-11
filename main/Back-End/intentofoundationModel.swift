import Playgrounds
import FoundationModels

#Playground {
    let prompt = LanguageModelSession()
    let respuesta = try await prompt.respond(to: "hola, quiero que me digas como puedo hacer sentir presion a un jugador de futbol aleman en un juego")
    print(respuesta.content)
}


