import AVFoundation
import UIKit

func extraerFrames(videoURL: URL, fps: Int) -> [UIImage] {
    var frames: [UIImage] = []
    //Aqui le pasamos la URL que queremos que analice desde la web
    let asset = AVAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let duracion = CMTimeGetSeconds(asset.duracion)
    var times=[NSValue]()
    
    var tiempoActual=0.0
    while tiempoActual < duracion {
        let cmTime = cmTime(seconds: current tiempoActual, preferredTimescale: 600)
        times.append(NSValue(time: cmTime))
        tiempoActual += seconds
    }
    // Guardamos la imagen de manera local
   for (index, timeValue) in times.enumerated() {
       do{
           let cgImage = try generator.copyCGImage(at: timeValue.timeValue , actualTime: nil)
           let image= UIImage(cgImage: cgImage)
           let nombreArchivo=FileManager.default.temporaryDirectory.appendingPathComponent("frame_\(index).jpg")
           if let data = image.jpegData(compressionQuality: 0.9){
               try data.write(to: nombreArchivo)
               print ("guardado:" \(nombreArchivo.path))
           }
       } catch {
           print ("No se pudo extraer la imagen")
       }
    }
    
}

// Busca el video de manera local, por ende tenemos que tener el video descargado antes aunque despues podemos cambiar esto
let home = NSHomeDirectory()
let buscarVideo = "\(home)/Descargas/video.mp4"
var url= URL(fileURLWithPath: buscarVideo)
extractFrames(from: url, every: 5)

