//
//  AquaVisionClient.swift
//  AquaVisionClient
//
//  Created by Otis Lin on 2026/5/24.
//

import Foundation
import Vision
import UIKit

// MARK: - 1. 定義對齊 API 的資料模型 (Codable)
struct Location: Codable {
    let latitude: Double
    let longitude: Double
}

struct AquaVisionInput: Codable {
    let event_id: String
    let image_url: String
    let location: Location
    let edge_ocr_text: String?
}

class AquaVisionClient {
    
    // 如果用 iOS 模擬器測試，127.0.0.1 沒問題。如果用 iPhone 實機測試，請改成 Mac 的 Wi-Fi IP (例如 http://192.168.1.xxx:8000/api/v1/analyze)
    let apiUrl = URL(string: "http://127.0.0.1:8000/api/v1/analyze")!
    
    // MARK: - 2. 實作 Vision Framework 邊緣端 OCR
    func extractTextFromImage(image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法轉換 CGImage"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: " ")
                continuation.resume(returning: fullText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - 3. 發送報告至 Python 後端 API
    func submitDisasterReport(image: UIImage, eventId: String, imageUrl: String, location: Location, ocrText: String) async throws -> String {
        
        let payload = AquaVisionInput(
            event_id: eventId,
            image_url: imageUrl,
            location: location,
            edge_ocr_text: ocrText.isEmpty ? nil : ocrText
        )
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return "❌ 無法取得有效的 HTTP 回應"
        }
        
        if httpResponse.statusCode == 200, let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        } else {
            return "❌ 請求失敗，狀態碼：\(httpResponse.statusCode)"
        }
    }
}
