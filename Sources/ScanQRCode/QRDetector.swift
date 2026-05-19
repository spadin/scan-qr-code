import Foundation
import Vision

/// Decodes 2D barcodes from an image using Apple's Vision framework.
///
/// Mirrors the reference `detect-qr.swift`: a single `VNDetectBarcodesRequest`
/// covering QR / Aztec / DataMatrix / PDF417, returning every non-empty
/// payload in detection order. An empty result is not an error.
struct QRDetector: QRDetecting {
    func detect(in imageURL: URL) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        // Vision handles perspective + contrast internally.
        request.symbologies = [.qr, .aztec, .dataMatrix, .pdf417]

        do {
            let handler = VNImageRequestHandler(url: imageURL, options: [:])
            try handler.perform([request])
        } catch {
            throw ScanError.detection(error.localizedDescription)
        }

        let results = request.results ?? []
        return results.compactMap { observation in
            guard let payload = observation.payloadStringValue, !payload.isEmpty else {
                return nil
            }
            return payload
        }
    }
}
