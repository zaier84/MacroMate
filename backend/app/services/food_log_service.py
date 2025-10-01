from sqlalchemy.orm import Session
from typing import Any
from datetime import datetime, date
import uuid

from app.models.sql_models import FoodEntry
from app.services.food_service import FoodAPIClient

def _generate_id() -> str:
    return uuid.uuid4().hex

class NotFoundError(Exception):
    pass

class FoodLogService:
    def __init__(self, db: Session):
        self.db = db
        self.food_api = FoodAPIClient()

    # -------------------------------
    # Create
    # -------------------------------
    def add_food_entries(
        self,
        user_id: str,
        day: date,
        meal_type: str,
        foods: list[dict[str, Any]],
        consumed_at: datetime | None = None
    ) -> list[dict[str, Any]]:
        """
        foods: list of dicts with keys name, quantity, unit, calories, protein_g, carbs_g, fats_g, food_api_id, raw
        """
        if not foods or not isinstance(foods, list):
            raise ValueError("foods must be a non-empty list")

        created = []
        for f in foods:
            entry_id = _generate_id()
            food_api_id = f.get("food_api_id")
            name = f.get("name") or (f.get("food_name") if f.get("food_name") else "Unknown")
            brand = f.get("brand")
            qty = f.get("quantity")
            unit = f.get("unit")
            calories = f.get("calories")
            protein = f.get("protein_g")
            carbs = f.get("carbs_g")
            fats = f.get("fats_g")
            raw = f.get("raw")

            # if calories missing and we have a provider id -> fetch details
            if (calories is None or protein is None or carbs is None or fats is None) and food_api_id:
                try:
                    details = self.food_api.get_details(food_api_id)
                    # fill only missing values
                    calories = calories if calories is not None else details.get("calories")
                    protein  = protein  if protein  is not None else details.get("protein_g")
                    carbs    = carbs    if carbs    is not None else details.get("carbs_g")
                    fats     = fats     if fats     is not None else details.get("fats_g")
                    raw = raw if raw is not None else details.get("raw")
                except Exception:
                    # ignore fetch errors; continue with whatever we have
                    pass

            consumed_at_ts = consumed_at or datetime.utcnow()

            entry = FoodEntry(
                entry_id=entry_id,
                user_id=user_id,
                date=day,
                meal_type=meal_type,
                consumed_at=consumed_at_ts,
                food_api_id=food_api_id,
                food_name=name,
                brand=brand,
                quantity=qty,
                unit=unit,
                calories=int(calories) if calories is not None else None,
                protein_g=float(protein) if protein is not None else None,
                carbs_g=float(carbs) if carbs is not None else None,
                fats_g=float(fats) if fats is not None else None,
                raw=raw
            )
            self.db.add(entry)
            created.append(entry)

        # commit batch
        self.db.commit()

        # Refresh created objects and return dictionaries
        for e in created:
            self.db.refresh(e)

        # return created entries as dict
        return [self._to_dict(e) for e in created]

    # -------------------------------
    # Read
    # -------------------------------
    def get_entry(self, entry_id: str, user_id: str) -> dict[str, Any] | None:
        row = (
            self.db.query(FoodEntry)
            .filter(FoodEntry.entry_id == entry_id, FoodEntry.user_id == user_id)
            .first()
        )
        return self._to_dict(row) if row else None

    def get_entries_by_day(self, user_id: str, day: date, limit: int = 100, offset: int = 0) -> list[dict[str, Any]]:
        rows = (
            self.db.query(FoodEntry)
            .filter(FoodEntry.user_id == user_id, FoodEntry.date == day)
            .order_by(FoodEntry.consumed_at.asc())
            .limit(limit)
            .offset(offset)
            .all()
        )

        return [self._to_dict(r) for r in rows]

    # -------------------------------
    # Update
    # -------------------------------
    def update_entry(self, entry_id: str, user_id: str, updates: dict[str, Any]) -> dict[str, Any]:
        """
        updates: allowed keys: ['quantity','unit','calories','protein_g','carbs_g','fats_g','food_name','brand','consumed_at','meal_type','date']
        """
        allowed = {"quantity","unit","calories","protein_g","carbs_g","fats_g","food_name","brand","consumed_at","meal_type","date"}
        row = (
            self.db.query(FoodEntry)
            .filter(FoodEntry.entry_id == entry_id, FoodEntry.user_id == user_id)
            .first()
        )
        if not row:
            raise NotFoundError("entry not found")

        for k, v in updates.items():
            if k not in allowed:
                continue

            if k in ("calories"):
                setattr(row, k, int(v) if v is not None else None)

            elif k in ("protein_g","carbs_g","fats_g","quantity"):
                setattr(row, k, int(v) if v is not None else None)

            elif k == "date":
                if isinstance(v, str):
                    setattr(row, k, datetime.fromisoformat(v))
                else:
                    setattr(row, k, v)

            elif k == "consumed_at":
                if isinstance(v, str):
                    setattr(row, k, datetime.fromisoformat(v))
                else:
                    setattr(row, k, v)
            else:
                setattr(row, k, v)

        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return self._to_dict(row)

    # -------------------------------
    # Delete
    # -------------------------------
    def delete_entry(self, entry_id: str, user_id: str) -> bool:
        row = (
            self.db.query(FoodEntry)
            .filter(FoodEntry.entry_id == entry_id, FoodEntry.user_id == user_id)
            .first()
        )
        if not row:
            raise NotFoundError("entry not found")

        self.db.delete(row)
        self.db.commit()
        return True

    def get_summary(self, user_id: str, day: date, user_summary: dict | None = None) -> dict[str, Any]:
        """
        Returns daily summary totals and meal grouping.
        Optionally take user_summary (from users.onboarding_summary) to include targets.
        """
        rows = self.db.query(FoodEntry).filter(FoodEntry.user_id == user_id, FoodEntry.date == day).all()
        total_cal = 0
        total_pro = 0
        total_carbs = 0
        total_fats = 0
        meals = {}
        for r in rows:
            c = r.calories or 0
            p = r.protein_g or 0
            ca = r.carbs_g or 0
            f = r.fats_g or 0
            total_cal += c
            total_pro += p
            total_carbs += ca
            total_fats += f
            meals.setdefault(r.meal_type, []).append(self._to_dict(r))

        target_cal = None
        target_macros = None
        if user_summary:
            target_cal = user_summary.get("daily_calories")
            target_macros = user_summary.get("macro_targets")

        return {
            "date": day.isoformat(),
            "totals": {
                "calories": int(total_cal),
                "protein_g": float(total_pro),
                "carbs_g": float(total_carbs),
                "fats_g": float(total_fats),
            },
            "targets": {
                "calories": target_cal,
                "macro_targets": target_macros
            },
            "meals": meals
        }

    def get_range_summary(
        self,
        user_id: str,
        start: date,
        end: date,
        user_summary: dict | None = None
    ) -> dict[str, Any]:
        """
        Aggregate entries from start to end date (inclusive).
        Returns daily breakdown + totals + averages.
        """
        rows = (
            self.db.query(FoodEntry)
            .filter(FoodEntry.user_id == user_id, FoodEntry.date >= start, FoodEntry.date <= end)
            .all()
        )

        per_day: dict[str, dict[str, Any]] = {}
        totals = {"calories": 0, "protein_g": 0.0, "carbs_g": 0.0, "fats_g": 0.0}

        for r in rows:
            d = r.date.isoformat()
            if d not in per_day:
                per_day[d] = {
                    "totals": {"calories": 0, "protein_g": 0.0, "carbs_g": 0.0, "fats_g": 0.0},
                    "meals": {}
                }

            c = r.calories or 0
            p = r.protein_g or 0.0
            ca = r.carbs_g or 0.0
            f = r.fats_g or 0.0

            per_day[d]["totals"]["calories"] += c
            per_day[d]["totals"]["protein_g"] += p
            per_day[d]["totals"]["carbs_g"] += ca
            per_day[d]["totals"]["fats_g"] += f
            per_day[d]["meals"].setdefault(r.meal_type, []).append(self._to_dict(r))

            totals["calories"] += c
            totals["protein_g"] += p
            totals["carbs_g"] += ca
            totals["fats_g"] += f

        num_days = (end - start).days + 1
        averages = {k: (v / num_days if num_days > 0 else 0) for k, v in totals.items()}
        
        return {
            "range": {"start": start.isoformat(), "end": end.isoformat()},
            "totals": totals,
            "averages": averages,
            "daily": per_day,
            "targets": {
                "calories": user_summary.get("daily_calories") if user_summary else None,
                "macro_targets": user_summary.get("macro_targets") if user_summary else None,
            },
        }

    # -------------------------------
    # Helpers
    # -------------------------------
    def _to_dict(self, e: FoodEntry) -> dict[str, Any]:
        return {
            "entry_id": e.entry_id,
            "user_id": e.user_id,
            "date": e.date.isoformat(),
            "meal_type": e.meal_type,
            "consumed_at": e.consumed_at.isoformat() if e.consumed_at else None,
            "food_api_id": e.food_api_id,
            "food_name": e.food_name,
            "brand": e.brand,
            "quantity": e.quantity,
            "unit": e.unit,
            "calories": e.calories,
            "protein_g": e.protein_g,
            "carbs_g": e.carbs_g,
            "fats_g": e.fats_g,
        }
        
