import Playgrounds
import FoundationModels

#Playground {
    let test = LanguageModelSession()
    let respuesta = try await test.respond(to: "hola, quiero que me digas como puedo hacer sentir presion a un jugador de futbol aleman en un juego")
    print(respuesta.content)
}


