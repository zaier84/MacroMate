from datetime import date, datetime
from collections import defaultdict
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.sql_models import FoodEntry, WeightEntry

class DiaryService:
    def __init__(self, db: Session):
        self.db = db

    def get_daily_diary(self, user_id: str, diary_date: date):
        # ─────────────────────────────
        # Fetch food logs
        # ─────────────────────────────
        foods = (
            self.db.query(FoodEntry)
            .filter(
                FoodEntry.user_id == user_id,
                FoodEntry.date == diary_date,
            )
            .order_by(FoodEntry.consumed_at.asc())
            # .order_by(FoodEntry.logged_at.asc())
            .all()
        )

        meals_map = defaultdict(list)

        for f in foods:
            meals_map[f.meal_type].append(f)

        meals_response = []

        for meal_type, items in meals_map.items():
            total_cal = sum(i.calories or 0 for i in items)
            total_protein = sum(i.protein_g or 0 for i in items)
            total_carbs = sum(i.carbs_g or 0 for i in items)
            total_fat = sum(i.fats_g or 0 for i in items)

            first_time = items[0].consumed_at
            # first_time = items[0].logged_at

            meals_response.append({
                "id": meal_type.lower(),
                "title": meal_type.title(),
                "time": first_time.strftime("%I:%M %p") if first_time else None,
                "totals": {
                    "calories": int(total_cal),
                    "protein": round(total_protein, 1),
                    "carbs": round(total_carbs, 1),
                    "fat": round(total_fat, 1),
                },
                "items": [
                    {
                        "id": item.entry_id,
                        "name": item.food_name,
                        "calories": int(item.calories or 0),
                        "protein": round(item.protein_g or 0, 1),
                        "carbs": round(item.carbs_g or 0, 1),
                        "fat": round(item.fats_g or 0, 1),
                    }
                    for item in items
                ],
            })

        # ─────────────────────────────
        # Weight (if logged that day)
        # ─────────────────────────────
        weight_entry = (
            self.db.query(WeightEntry)
            .filter(
                WeightEntry.user_id == user_id,
                WeightEntry.date == diary_date,
            )
            .first()
        )

        weight_block = {
            "value": weight_entry.weight_kg if weight_entry else None,
            "unit": "kg",
            "logged": bool(weight_entry),
        }

        # ─────────────────────────────
        # Water placeholder (future)
        # ─────────────────────────────
        water_block = {
            "value": 0.0,
            "unit": "L",
            "goal": 3.0,
        }

        # ─────────────────────────────
        # Final response
        # ─────────────────────────────
        return {
            "date": diary_date.isoformat(),
            "meals": meals_response,
            "weight": weight_block,
            "otherLogs": {
                "water": water_block
            }
        }

