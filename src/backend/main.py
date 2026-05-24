from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl
from typing import Optional, List
from datetime import datetime, timezone

app = FastAPI(
    title="AquaVision Block API",
    description="防災積木元件創新賽 - 堰塞湖影像災情結構化解析元件",
    version="1.0.0"
)

# --- 1. 定義輸入資料模型 (對齊 Input Schema) ---
class Location(BaseModel):
    latitude: float
    longitude: float

class AquaVisionInput(BaseModel):
    event_id: str
    image_url: HttpUrl
    location: Location
    edge_ocr_text: Optional[str] = None

# --- 2. 實作 API 路由 ---
@app.post("/api/v1/analyze")
async def analyze_image_report(payload: AquaVisionInput):
    """
    接收前端影像與座標，進行多模態災情分析 (MVP 模擬版)
    """
    try:
        # 在實際運作中，這裡會將 payload.image_url 與 payload.edge_ocr_text
        # 送給 Gemini 或 Claude 的 Vision API 進行推論。
        # 為了比賽 MVP 驗證資料流，我們這裡先實作 Mock 邏輯。
        
        # 模擬 AI 處理時間與決策邏輯
        mock_turbidity = "high"
        mock_risk = "warning"
        mock_confidence = 0.85
        
        # 組合標準化 GeoJSON
        geojson = {
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [payload.location.longitude, payload.location.latitude]
            },
            "properties": {
                "urgency": "high",
                "primary_tag": "堰塞湖高濁度",
                "display_title": f"災情通報: {payload.event_id}"
            }
        }

        # 回傳對齊 Output Schema 的結果
        return {
            "status": "success",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "analysis_result": {
                "turbidity_level": mock_turbidity,
                "barrier_risk": mock_risk,
                "confidence_score": mock_confidence,
                "requires_human_review": mock_confidence < 0.6,
                "extracted_features": [
                    "水體呈現黃褐色",
                    "邊緣預讀文字確認:",
                    payload.edge_ocr_text or "無前端提供之文字"
                ]
            },
            "standardized_geojson": geojson
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 讓程式可以直接執行
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
