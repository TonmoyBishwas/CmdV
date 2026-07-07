import Foundation
import Vision

/// Local text recognition for copied images (Apple Vision — fully offline)
/// so screenshots become searchable.
enum OCRService {
    static func recognizeText(in imageData: Data) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(data: imageData)
                do {
                    try handler.perform([request])
                    let text = (request.results ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: text.isEmpty ? nil : text)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
