from typing import Any
import requests
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

class FoodAPIClient:
    def __init__(self):
        self.provider = getattr(settings, "FOOD_API_PROVIDER", "usda").lower()
        self.usda_key = getattr(settings, "USDA_API_KEY", None)
        if self.provider == "usda" and not self.usda_key:
            logger.warning("USDA_API_KEY not set in settings - search will fail for USDA provider")

    # ---------- PUBLIC ----------
    def search(self, query: str, page: int = 1, page_size: int = 25) -> dict[str, Any]:
        if self.provider == "usda":
            return self._search_usda(query, page, page_size)
        raise NotImplementedError("Only USDA provider is implemented in this client (you can extend it)")

    def get_details(self, food_id: str) -> dict[str, Any]:
        if self.provider == "usda":
            return self._get_details_usda(food_id)
        raise NotImplementedError("Only USDA provider is implemented in this client")

    # ---------- USDA implementation ----------
    def _search_usda(self, query: str, page: int = 1, page_size: int = 25) -> dict[str, Any]:
        url = f"https://api.nal.usda.gov/fdc/v1/foods/search?api_key={self.usda_key}"
        payload = {
            "query": query,
            "pageNumber": page,
            "pageSize": page_size,
        }
        resp = requests.post(url, json=payload, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        results = []
        for f in data.get("foods", []):
            item = self._map_usda_shallow(f)
            results.append(item)
        return {"totalHits": data.get("totalHits", 0), "foods": results}

    def _get_details_usda(self, fdc_id: str) -> dict[str, Any]:
        url = f"https://api.nal.usda.gov/fdc/v1/{fdc_id}?api_key={self.usda_key}"
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        return self._map_usda_detailed(data)

    # ---------- mappers ----------
    def _map_usda_shallow(self, f: dict[str, Any]) -> dict[str, Any]:
        # fields vary by dataType; best guess
        fdc_id = str(f.get("fdcId") or f.get("id"))
        name = f.get("description") or f.get("lowercaseDescription") or f.get("description")
        brand = f.get("brandOwner")
        serving_size = None
        if f.get("servingSize"):
            serving_size = f.get("servingSize")
            unit = f.get("servingSizeUnit")
            serving_size = f"{serving_size} {unit}" if unit else str(serving_size)
        # quick attempt to extract labelNutrients if present
        label_nutrients = f.get("labelNutrients", {}) or {}
        calories = label_nutrients.get("calories", {}).get("value")
        protein = label_nutrients.get("protein", {}).get("value")
        carbs = label_nutrients.get("carbohydrates", {}).get("value")
        fat = label_nutrients.get("fat", {}).get("value")

        # fallback: look in "foodNutrients" list
        if calories is None:
            for nut in f.get("foodNutrients", []) or []:
                nname = (nut.get("nutrientName") or "").lower()
                if "energy" in nname and calories is None:
                    calories = nut.get("value")
                if "protein" in nname and protein is None:
                    protein = nut.get("value")
                if "carbohydrate" in nname and carbs is None:
                    carbs = nut.get("value")
                if "lipid" in nname and fat is None:
                    fat = nut.get("value")

        return {
            "provider": "usda",
            "id": fdc_id,
            "name": name,
            "brand": brand,
            "serving": serving_size,
            "calories": round(float(calories)) if calories is not None else None,
            "protein_g": float(protein) if protein is not None else None,
            "carbs_g": float(carbs) if carbs is not None else None,
            "fats_g": float(fat) if fat is not None else None,
        }

    def _map_usda_detailed(self, data: dict[str, Any]) -> dict[str, Any]:
        # Similar mapping but include raw nutrients array
        mapped = self._map_usda_shallow(data)
        # attach full nutrient list
        mapped["raw"] = data
        return mapped
