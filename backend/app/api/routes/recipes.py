from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Any
from app.auth.deps import Principal, get_current_user
from app.api.deps import get_meal_service
from app.services.meal_service import MealService

router = APIRouter(prefix="/recipes", tags=["recipes"])

class IngredientIn(BaseModel):
    food_api_id: str | None = None
    name: str
    quantity: float | None = None
    unit: str | None = None
    calories: int | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fats_g: float | None = None
    raw: Any | None = None

class RecipeIn(BaseModel):
    title: str = Field(..., json_schema_extra={"example": "Oatmeal with banana"})
    description: str | None = None
    servings: float = Field(..., json_schema_extra={"example":1.0})
    ingredients: list[IngredientIn]

@router.post("/", status_code=status.HTTP_201_CREATED)
def create_recipe(payload: RecipeIn, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    try:
        r = svc.create_recipe(user.uid, payload.dict())
        return r
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/", status_code=status.HTTP_200_OK)
def list_recipes(user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    return svc.list_recipes(user.uid)

@router.get("/{recipe_id}", status_code=status.HTTP_200_OK)
def get_recipe(recipe_id: str, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    r = svc.get_recipe(recipe_id, user.uid)
    if not r:
        raise HTTPException(status_code=404, detail="Not found")
    return r

@router.delete("/{recipe_id}", status_code=status.HTTP_200_OK)
def delete_recipe(recipe_id: str, user: Principal = Depends(get_current_user), svc: MealService = Depends(get_meal_service)):
    ok = svc.delete_recipe(recipe_id, user.uid)
    if not ok:
        raise HTTPException(status_code=404, detail="Not found")
    return {"ok": True}
