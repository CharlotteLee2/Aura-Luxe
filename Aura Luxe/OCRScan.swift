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
        let request = VNRecognizeTextRequest { request, error in
            guard let results = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }

            let strings = results.compactMap { $0.topCandidates(1).first?.string }
            completion(strings)
        }

        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: image.cgImage!)
        try? handler.perform([request])
    }
}
