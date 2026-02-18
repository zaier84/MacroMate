from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from app.auth.deps import get_current_user, Principal
from app.services.meal_snap_analyzer import MealSnapAnalyzer
from app.core.config import settings

router = APIRouter(prefix="/ai", tags=["AI"])


@router.post("/snap-meal", status_code=status.HTTP_200_OK)
async def snap_meal(
    file: UploadFile = File(...),
    user: Principal = Depends(get_current_user),
):
    if file.content_type not in ("image/jpeg", "image/png", "application/octet-stream"):
        raise HTTPException(
            status_code=400,
            detail="Only JPEG or PNG images are supported",
        )

    image_bytes = await file.read()

    analyzer = MealSnapAnalyzer(
        api_key=settings.GEMINI_API_KEY
    )

    try:
        result = analyzer.analyze_meal_image(image_bytes)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e),
        )

