import UIKit
import Vision

enum OCRService {
    static func recognizeText(in image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        } catch {
            Loggers.ocr.error("OCR failed: \(error.localizedDescription)")
            return ""
        }
    }
}

