import Foundation
import Combine

class DinamicaViewModel: ObservableObject {
    @Published var dinamicaActual: String = ""
    
    func mostrarDinamica(_ dinamica: String) {
        DispatchQueue.main.async {
            self.dinamicaActual = dinamica
        }
    }
}