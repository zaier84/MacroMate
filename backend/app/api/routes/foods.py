from fastapi import APIRouter, Depends, HTTPException, Query

from app.services.food_service import FoodAPIClient
from app.auth.deps import Principal, get_current_user

router = APIRouter(prefix="/foods", tags=["foods"])
food_api = FoodAPIClient()

@router.get("/search")
def search_foods(q: str = Query(..., min_length=1), page: int = 1, page_size: int = 25, user: Principal = Depends(get_current_user)):
    try:
        return food_api.search(q, page=page, page_size=page_size)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Food API error: {e}")

@router.get("/{food_id}")
def food_details(food_id: str, user: Principal = Depends(get_current_user)):
    try:
        return food_api.get_details(food_id)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Food API error: {e}")
