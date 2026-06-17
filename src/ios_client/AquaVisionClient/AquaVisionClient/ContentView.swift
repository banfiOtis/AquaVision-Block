//
//  ContentView.swift
//  AquaVisionClient
//
//  Created by Otis Lin on 2026/5/24.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    // 狀態變數：用來儲存選取的照片、選取狀態、OCR 辨識結果與 API 回傳結果
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var ocrResultText = "尚未辨識"
    @State private var apiResponseText = ""
    
    // 建立我們剛剛寫好的 Client 實體
    private let visionClient = AquaVisionClient()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("AquaVision 災情通報")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // --- 1. 照片顯示與選取區塊 ---
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(Text("請選擇一張災情照片").foregroundColor(.secondary))
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label("從相簿選取照片", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        // 當使用者選好照片後，將其轉換為 UIImage
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                            ocrResultText = "尚未辨識" // 重置狀態
                            apiResponseText = ""
                        }
                    }
                }
                
                // --- 2. 邊緣運算與通報按鈕 ---
                Button(action: {
                    if let image = selectedImage {
                        processAndSubmit(image: image)
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        }
                        Text(isProcessing ? "處理中..." : "開始邊緣辨識並通報")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedImage == nil || isProcessing ? Color.gray : Color.red)
                    .cornerRadius(10)
                }
                .disabled(selectedImage == nil || isProcessing)
                
                // --- 3. 結果顯示區塊 ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("邊緣端 OCR 結果：")
                        .font(.headline)
                    Text(ocrResultText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                    
                    Text("雲端 API 解析結果：")
                        .font(.headline)
                    Text(apiResponseText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
    }
    
    // MARK: - 處理邏輯
    private func processAndSubmit(image: UIImage) {
        isProcessing = true
        apiResponseText = "正在上傳至 API..."
        
        Task {
            do {
                // 1. 先在本地端跑 Vision OCR
                ocrResultText = "Vision OCR 辨識中..."
                let text = try await visionClient.extractTextFromImage(image: image)
                ocrResultText = text.isEmpty ? "未辨識到文字" : text
                
                // 2. 隨機生成馬太鞍溪附近的座標 (讓戰情地圖點位更真實散佈)
                // 基準點：馬太鞍濕地周邊
                let baseLat = 23.6543
                let baseLon = 121.4321

                // 隨機偏移量：大約 -0.015 到 +0.015 度 (約半徑 1.5 公里內隨機散佈)
                let randomLat = baseLat + Double.random(in: -0.015...0.015)
                let randomLon = baseLon + Double.random(in: -0.015...0.015)

                let mockLocation = Location(latitude: randomLat, longitude: randomLon)
                
                // 3. 呼叫 API 送出資料 (假設你用本機測試)
                // 注意：實機測試時，請將 AquaVisionClient 裡的 localhost 改為你 Mac 的 IP 網址
                let response = try await visionClient.submitDisasterReport(
                    image: image,
                    eventId: "mataian_202509_test",
                    imageUrl: "https://example.com/uploaded_image_mock.jpg",
                    location: mockLocation,
                    ocrText: text // 這裡把剛才抓到的文字塞進去！
                )
                
                // 4. 更新畫面
                apiResponseText = response
                
            } catch {
                apiResponseText = "發生錯誤：\(error.localizedDescription)"
            }
            
            isProcessing = false
        }
    }
}
