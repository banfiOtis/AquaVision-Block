import os
import json
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone
import google.generativeai as genai

app = FastAPI(
    title="AquaVision Block API",
    description="防災積木元件創新賽 - 堰塞湖影像災情結構化解析元件",
    version="1.0.0"
)

# 🌟 新增：用來暫存所有災情通報的記憶體資料庫 (MVP 測試用)
reports_db = []

# --- 1. 初始化 Google Gemini API ---
genai.configure(api_key=os.environ.get("GEMINI_API_KEY", "你的_GEMINI_API_KEY_放這裡"))
# 使用最新模型 (請根據你的可用狀態調整為 3.1-flash-lite 或 3.5-flash)
model = genai.GenerativeModel('gemini-3.1-flash-lite')

# --- 2. 定義輸入資料模型 ---
class Location(BaseModel):
    latitude: float
    longitude: float

class AquaVisionInput(BaseModel):
    event_id: str
    image_url: Optional[str] = None
    location: Location
    edge_ocr_text: Optional[str] = None
    image_base64: Optional[str] = None

# --- 3. 實作 API 路由 ---
@app.post("/api/v1/analyze")
async def analyze_image_report(payload: AquaVisionInput):
    try:
        analysis_result = {
            "turbidity_level": "unknown",
            "barrier_risk": "unknown",
            "confidence_score": 0.0,
            "requires_human_review": True,
            "extracted_features": ["未提供有效影像"]
        }

        if payload.image_base64:
            base64_data = payload.image_base64
            mime_type = "image/jpeg"
            if "," in base64_data:
                header, base64_data = base64_data.split(",", 1)
                if ":" in header and ";" in header:
                    mime_type = header.split(":")[1].split(";")[0]

            image_part = {
                "mime_type": mime_type,
                "data": base64_data
            }

            prompt = f"""
            你是一個專業的防災影像分析 AI。請分析這張災情現場照片，並以 JSON 格式回傳分析結果。
            現場手機端初步辨識到的文字為：'{payload.edge_ocr_text or "無提供"}'，請參考此文字資訊輔助判斷。
            回傳的 JSON 必須包含以下欄位：
            - "turbidity_level": 水體混濁度 (請填寫: low, medium, 或 high)
            - "barrier_risk": 堰塞湖或水位風險 (請填寫: safe, warning, 或 danger)
            - "confidence_score": 你的判斷信心分數 (0.0 到 1.0 的浮點數)
            - "extracted_features": 包含 3~5 項具體觀察特徵的字串陣列
            """

            response = model.generate_content(
                [prompt, image_part],
                generation_config=genai.GenerationConfig(response_mime_type="application/json")
            )

            ai_data = json.loads(response.text)
            analysis_result = {
                "turbidity_level": ai_data.get("turbidity_level", "unknown"),
                "barrier_risk": ai_data.get("barrier_risk", "unknown"),
                "confidence_score": float(ai_data.get("confidence_score", 0.5)),
                "requires_human_review": float(ai_data.get("confidence_score", 0.5)) < 0.7,
                "extracted_features": ai_data.get("extracted_features", [])
            }

        geojson = {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [payload.location.longitude, payload.location.latitude]
            },
            "properties": {
                "urgency": "high" if analysis_result["barrier_risk"] == "danger" else "medium",
                "primary_tag": f"風險:{analysis_result['barrier_risk']}",
                "display_title": f"災情通報: {payload.event_id}"
            }
        }

        final_response = {
            "status": "success",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "analysis_result": analysis_result,
            "standardized_geojson": geojson
        }

        # 🌟 儲存進暫存資料庫
        reports_db.insert(0, final_response) # 將最新資料插在最前面

        return final_response

    except Exception as e:
        print(f"API Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# 🌟 新增：取得所有報告的 API (供戰情室抓取)
@app.get("/api/v1/reports")
async def get_all_reports():
    return {"reports": reports_db}

# 🌟 新增：戰情室 Dashboard 網頁 (HTML+JS)
@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard():
    html_content = """
    <!DOCTYPE html>
    <html lang="zh-TW">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>AquaVision 災情戰情室</title>
        <!-- 引入 Leaflet 地圖套件 -->
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; display: flex; height: 100vh; background-color: #f4f7f6; }
            #sidebar { width: 400px; background: white; overflow-y: auto; padding: 20px; box-shadow: 2px 0 5px rgba(0,0,0,0.1); z-index: 1000; }
            #map { flex-grow: 1; height: 100%; }
            h2 { color: #2c3e50; margin-top: 0; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
            .report-card { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; padding: 15px; margin-bottom: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
            .danger { border-left: 5px solid #e74c3c; }
            .warning { border-left: 5px solid #f39c12; }
            .safe { border-left: 5px solid #2ecc71; }
            .time { font-size: 0.85em; color: #7f8c8d; margin-bottom: 5px; }
            .tag { display: inline-block; padding: 3px 8px; border-radius: 12px; font-size: 0.8em; font-weight: bold; color: white; }
            .tag-danger { background-color: #e74c3c; }
            .tag-warning { background-color: #f39c12; }
            .tag-safe { background-color: #2ecc71; }
            .features { font-size: 0.9em; color: #34495e; margin-top: 10px; padding-left: 15px; }
            .features li { margin-bottom: 4px; }
        </title>
        </style>
    </head>
    <body>
        <div id="sidebar">
            <h2>🚨 即時災情列表</h2>
            <div id="report-list">載入中...</div>
        </div>
        <div id="map"></div>

        <script>
            // 初始化地圖，中心點設定在台灣 (經緯度)
            const map = L.map('map').setView([23.6543, 120.9321], 8);
            
            // 載入 OpenStreetMap 圖資
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(map);

            let currentMarkers = [];

            // 定期抓取最新資料的函數
            async function fetchReports() {
                try {
                    const response = await fetch('/api/v1/reports');
                    const data = await response.json();
                    updateDashboard(data.reports);
                } catch (error) {
                    console.error('抓取資料失敗:', error);
                }
            }

            // 更新畫面與地圖
            function updateDashboard(reports) {
                const listDiv = document.getElementById('report-list');
                listDiv.innerHTML = '';
                
                // 清除地圖上舊的標記
                currentMarkers.forEach(marker => map.removeLayer(marker));
                currentMarkers = [];

                if(reports.length === 0) {
                    listDiv.innerHTML = '<p>目前尚無災情通報。</p>';
                    return;
                }

                reports.forEach(report => {
                    const coords = report.standardized_geojson.geometry.coordinates; // [lon, lat]
                    const lat = coords[1];
                    const lon = coords[0];
                    const risk = report.analysis_result.barrier_risk;
                    const features = report.analysis_result.extracted_features;
                    const timeStr = new Date(report.timestamp).toLocaleString('zh-TW');

                    // 決定顏色
                    let color = 'green';
                    let tagClass = 'tag-safe';
                    let riskText = '安全';
                    if (risk === 'danger') { color = 'red'; tagClass = 'tag-danger'; riskText = '危險'; }
                    else if (risk === 'warning') { color = 'orange'; tagClass = 'tag-warning'; riskText = '警告'; }

                    // --- 1. 更新地圖標記 (使用圓形標記比較好自訂顏色) ---
                    const marker = L.circleMarker([lat, lon], {
                        color: color,
                        fillColor: color,
                        fillOpacity: 0.7,
                        radius: 12
                    }).addTo(map);
                    
                    // 點擊地圖標記時跳出資訊
                    marker.bindPopup(`<b>${report.standardized_geojson.properties.display_title}</b><br>狀態: ${riskText}<br>時間: ${timeStr}`);
                    currentMarkers.push(marker);

                    // --- 2. 更新側邊欄列表 ---
                    const card = document.createElement('div');
                    card.className = `report-card ${risk}`;
                    
                    let featuresHtml = features.map(f => `<li>${f}</li>`).join('');
                    
                    card.innerHTML = `
                        <div class="time">🕒 ${timeStr}</div>
                        <strong>${report.standardized_geojson.properties.display_title}</strong><br>
                        <div style="margin-top: 8px;">
                            <span class="tag ${tagClass}">風險: ${riskText}</span>
                            <span class="tag" style="background: #34495e;">信心度: ${Math.round(report.analysis_result.confidence_score * 100)}%</span>
                        </div>
                        <ul class="features">${featuresHtml}</ul>
                    `;
                    
                    // 點擊卡片時，地圖會飛過去
                    card.style.cursor = 'pointer';
                    card.onclick = () => map.flyTo([lat, lon], 14);

                    listDiv.appendChild(card);
                });
            }

            // 啟動：先抓一次，然後每 5 秒更新一次
            fetchReports();
            setInterval(fetchReports, 5000);
        </script>
    </body>
    </html>
    """
    return html_content

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
