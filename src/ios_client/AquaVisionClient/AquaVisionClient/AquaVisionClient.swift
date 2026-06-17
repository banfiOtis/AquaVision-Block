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
    let image_url: String?      // 改為 Optional，因為我們現在直接傳照片了
    let location: Location
    let edge_ocr_text: String?
    let image_base64: String?   // 🌟 新增：用來傳送實體照片的 Base64 欄位
}

class AquaVisionClient {
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
        
        // 🌟 步驟 A：將圖片縮小並轉成 Base64
        guard let resizedImage = image.resized(toWidth: 800),
              let base64String = resizedImage.toBase64(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "圖片轉換 Base64 失敗"])
        }
        
        // 🌟 步驟 B：加上大模型需要的 MIME Type 前綴
        let imageBase64WithPrefix = "data:image/jpeg;base64,\(base64String)"
        
        // 🌟 步驟 C：組合新的 Payload
        let payload = AquaVisionInput(
            event_id: eventId,
            image_url: imageUrl,
            location: location,
            edge_ocr_text: ocrText.isEmpty ? nil : ocrText,
            image_base64: imageBase64WithPrefix // 將照片放進 JSON
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

// MARK: - 4. UIImage 擴充功能 (壓縮與轉 Base64)
extension UIImage {
    // 等比例縮放圖片 (避免 JSON 檔案過大)
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // 轉為 Base64 字串
    func toBase64(compressionQuality: CGFloat = 0.7) -> String? {
        guard let imageData = self.jpegData(compressionQuality: compressionQuality) else { return nil }
        return imageData.base64EncodedString()
    }
}
