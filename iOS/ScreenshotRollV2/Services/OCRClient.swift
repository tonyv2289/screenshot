import UIKit
import Vision

actor OCRClient {
    static let shared = OCRClient()

    func recognizeText(in image: UIImage) async -> String {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return "" }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

            do {
                try handler.perform([request])
                return (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
            } catch {
                return ""
            }
        }.value
    }
}
