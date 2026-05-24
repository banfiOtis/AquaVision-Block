
# AquaVision Block (水情視覺解析元件)

![iOS](https://img.shields.io/badge/iOS-16.0+-black?logo=apple)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Edge_OCR-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?logo=fastapi)
![License](https://img.shields.io/badge/License-MIT-green)

> **2025 數位發展部 防災積木元件創新賽 參賽作品**

https://github.com/user-attachments/assets/c6268f6b-4df0-4631-8ffb-10d0697c7400

## 📌 元件基本資訊
* **元件實作型態：** API 服務型元件 (Service Component)
* **聚焦災情情境：** 2025 年 9 月花蓮馬太鞍溪堰塞湖災害事件
* **核心聚焦功能：** 通報 (Call) & AI 應用

---

## 1. 元件之功能定位與欲解決問題之說明

### 🚨 待解決問題
在花蓮馬太鞍溪堰塞湖危機中，前線巡守人員或民眾回報災情常依賴通訊軟體（如 LINE、Telegram）傳送照片與簡短文字。這些**非結構化資料**需要災防中心耗費大量人力進行人工判讀，且容易漏掉關鍵資訊（如環境中的水尺刻度、電線桿標號、水體混濁度變化），導致決策延遲與資源錯置。

### 💡 解法與功能定位
**AquaVision Block** 是一個「隨插即用」的視覺解析 API 元件。其功能定位為**「非結構化影像通報與災防決策系統之間的轉譯器」**。
它能接收來自任何前端通訊管道（如 LINE Bot、iOS 捷徑、Web 表單）的「現場影像 + GPS」輸入，運用邊緣端 OCR 與雲端多模態 AI，自動擷取照片中的關鍵數據（如水位高度、地標文字、水體混濁狀態），並轉換為機器可讀的標準化 JSON (GeoJSON) 格式，直接無縫對接決策儀表板或其他分析系統。

---

## 2. 使用流程與系統架構圖

本元件採用「邊緣與雲端協作」架構，利用前端設備（如 iOS 裝置）進行初步特徵提取，再交由後端 API 進行深度多模態推論。

```mermaid
sequenceDiagram
    participant FrontEnd as 前端設備 (iOS App / LINE Bot)
    participant API as AquaVision Block API (Server)
    participant AI as 多模態大語言模型
    participant System as 下游災防決策系統

    FrontEnd->>FrontEnd: Vision Framework 前處理 (OCR / Object Capture)
    FrontEnd->>API: HTTP POST (影像, GPS, OCR 預取文字)
    API->>AI: 組合 Prompt 請求分析 (堰塞湖水情特徵)
    AI-->>API: 回傳結構化分析結果
    API->>API: 格式化為 GeoJSON / 標準 JSON Schema
    API-->>FrontEnd: 回傳成功狀態
    API->>System: Webhook 推送結構化數據 (觸發警報或標記地圖)
