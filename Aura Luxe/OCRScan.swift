//
//  OCRScan.swift
//  Aura Luxe
//
//  Created by CharlotteLee on 11/24/25.
//

import Vision
import UIKit

class OCRScan {
    static let shared = OCRScan()

    func recognizeText(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else { completion([]); return }
        let request = VNRecognizeTextRequest { request, _ in
            let strings = (request.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            completion(strings)
        }
        request.recognitionLevel = .accurate
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
    }

    func recognizeText(from image: UIImage) async -> [String] {
        await withCheckedContinuation { continuation in
            recognizeText(from: image) { continuation.resume(returning: $0) }
        }
    }

    func recognizeTextWithBounds(from image: UIImage) async -> [(text: String, rect: CGRect)] {
        await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: [])
                return
            }
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let result = observations.compactMap { obs -> (String, CGRect)? in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    return (text, obs.boundingBox)
                }
                continuation.resume(returning: result)
            }
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
}
