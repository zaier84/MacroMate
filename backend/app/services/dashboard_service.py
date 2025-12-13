from datetime import date, timedelta
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.services.food_log_service import FoodLogService
from app.services.nutrition_service import NutritionService
from app.services.weight_service import WeightService
from app.services.workout_service import WorkoutService
from app.models.sql_models import FoodEntry, WeightEntry, WorkoutSession, ExerciseEntry

def _date_range(start: date, end: date) -> list[date]:
    days = (end - start).days
    return [start + timedelta(days=i) for i in range(days + 1)]

def _macros_from_percentages(calories: int, protein_pct: int, carbs_pct: int, fat_pct: int) -> dict[str, int]:
    """Return grams for protein, carbs, fats given calorie totals and percentages."""
    from math import floor

    protein_g = floor((calories * protein_pct / 100.0) / 4.0)
    carbs_g = floor((calories * carbs_pct / 100.0) / 4.0)
    fats_g = floor((calories * fat_pct / 100.0) / 9.0)
    return {"protein_g": int(protein_g), "carbs_g": int(carbs_g), "fats_g": int(fats_g),
            "protein_pct": protein_pct, "carbs_pct": carbs_pct, "fat_pct": fat_pct}

class DashboardService:
    def __init__(self, db: Session):
        self.db = db
        self.food_svc = FoodLogService(db)
        self.nutrition_svc = NutritionService(db)
        self.weight_svc = WeightService(db)
        self.workout_svc = WorkoutService(db)

    # --------------------------
    # Daily dashboard
    # --------------------------
    def get_daily_dashboard(self, user_id: str, day: date) -> dict[str, Any]:
        """
        Returns:
         {
           "date": "YYYY-MM-DD",
           "base": { calories, macro_targets },
           "adjusted": { calories, macro_targets },
           "intake": { totals, meals, targets },
           "progress": { calories_pct, protein_pct, ... , remaining_calories, remaining_protein... },
           "metabolic_adjustment_kcal": float,
           "weekly_goal": ???,
         }
        """
        # nutrition service returns base & adjusted + metadata (this matches your current implementation)
        nutrition = self.nutrition_svc.get_daily_nutrition(user_id)

        # food intake summary for the date (FoodLogService already supports targets)
        # Try to supply the onboarding_summary to FoodLogService.get_summary so it can put targets
        # We'll fetch user onboarding summary through nutrition service's internals (it already loads it)
        # But to avoid tight coupling, pass None; FoodLogService will produce totals.
        intake = self.food_svc.get_summary(user_id, day, user_summary=None)

        base = nutrition.get("base") or {"calories": None, "macro_targets": {}}
        adjusted = nutrition.get("adjusted") or {"calories": None, "macro_targets": {}}

        # totals
        totals = intake.get("totals", {"calories": 0, "protein_g": 0, "carbs_g": 0, "fats_g": 0})
        def safe_float(x): return 0.0 if x is None else float(x)
        consumed_cal = int(totals.get("calories", 0) or 0)
        consumed_pro = float(totals.get("protein_g", 0) or 0)
        consumed_carbs = float(totals.get("carbs_g", 0) or 0)
        consumed_fats = float(totals.get("fats_g", 0) or 0)

        # Use ADJUSTED targets for remaining/progress (user sees the adjusted target)
        adj_cal = int(adjusted.get("calories") or base.get("calories") or 0)
        adj_macros = adjusted.get("macro_targets") or base.get("macro_targets") or {}
        # If macro grams absent but percentages provided, compute grams
        if not any(k in adj_macros for k in ("protein_g", "carbs_g", "fats_g")):
            p_pct = int(adj_macros.get("protein_pct", 30))
            c_pct = int(adj_macros.get("carbs_pct", 50))
            f_pct = int(adj_macros.get("fat_pct", 20))
            adj_macros = _macros_from_percentages(adj_cal, p_pct, c_pct, f_pct)

        remaining_cal = max(0, adj_cal - consumed_cal)
        remaining_pro = max(0.0, adj_macros.get("protein_g", 0) - consumed_pro)
        remaining_carbs = max(0.0, adj_macros.get("carbs_g", 0) - consumed_carbs)
        remaining_fats = max(0.0, adj_macros.get("fats_g", 0) - consumed_fats)

        def pct(consumed, target):
            try:
                if target and target > 0:
                    return round(float(consumed) * 100.0 / float(target), 1)
            except Exception:
                pass
            return 0.0

        progress = {
            "calories_pct": pct(consumed_cal, adj_cal),
            "protein_pct": pct(consumed_pro, adj_macros.get("protein_g")),
            "carbs_pct": pct(consumed_carbs, adj_macros.get("carbs_g")),
            "fats_pct": pct(consumed_fats, adj_macros.get("fats_g")),
            "remaining": {
                "calories": remaining_cal,
                "protein_g": remaining_pro,
                "carbs_g": remaining_carbs,
                "fats_g": remaining_fats,
            }
        }

        return {
            "date": day.isoformat(),
            "base": base,
            "adjusted": adjusted,
            "intake": intake,
            "progress": progress,
            "metabolic_adjustment_kcal": float(nutrition.get("metabolic_adjustment_kcal", 0.0) or 0.0),
            "weekly_goal": nutrition.get("weekly_goal")
        }

    # --------------------------
    # Time-series helper
    # --------------------------
    def get_time_series(self, user_id: str, start: date, end: date) -> dict[str, Any]:
        """
        Returns daily arrays for calories/protein/carbs/fats/weight/workout_volume between start..end inclusive.
        """
        if end < start:
            raise ValueError("end must be >= start")

        # Food aggregates by date
        food_q = (
            self.db.query(
                FoodEntry.date.label("d"),
                func.coalesce(func.sum(FoodEntry.calories), 0).label("calories"),
                func.coalesce(func.sum(FoodEntry.protein_g), 0).label("protein_g"),
                func.coalesce(func.sum(FoodEntry.carbs_g), 0).label("carbs_g"),
                func.coalesce(func.sum(FoodEntry.fats_g), 0).label("fats_g"),
            )
            .filter(FoodEntry.user_id == user_id, FoodEntry.date >= start, FoodEntry.date <= end)
            .group_by(FoodEntry.date)
        )
        food_rows = {r.d: {"calories": int(r.calories), "protein_g": float(r.protein_g),
                           "carbs_g": float(r.carbs_g), "fats_g": float(r.fats_g)} for r in food_q.all()}

        # Weight aggregates by date (take latest weight of the day) — use MAX(weight)
        weight_q = (
            self.db.query(WeightEntry.date.label("d"), func.max(WeightEntry.weight_kg).label("weight_kg"))
            .filter(WeightEntry.user_id == user_id, WeightEntry.date >= start, WeightEntry.date <= end)
            .group_by(WeightEntry.date)
        )
        weight_rows = {r.d: float(r.weight_kg) for r in weight_q.all()}

        # Workout volume by session date (join exercise_entries -> workout_sessions)
        vol_q = (
            self.db.query(WorkoutSession.date.label("d"), func.coalesce(func.sum(ExerciseEntry.total_volume), 0).label("volume"))
            .join(ExerciseEntry, ExerciseEntry.session_id == WorkoutSession.session_id)
            .filter(WorkoutSession.user_id == user_id, WorkoutSession.date >= start, WorkoutSession.date <= end)
            .group_by(WorkoutSession.date)
        )
        vol_rows = {r.d: float(r.volume) for r in vol_q.all()}

        series = []
        for d in _date_range(start, end):
            fd = food_rows.get(d, {"calories": 0, "protein_g": 0.0, "carbs_g": 0.0, "fats_g": 0.0})
            series.append({
                "date": d.isoformat(),
                "calories": int(fd["calories"]),
                "protein_g": float(fd["protein_g"]),
                "carbs_g": float(fd["carbs_g"]),
                "fats_g": float(fd["fats_g"]),
                "weight_kg": weight_rows.get(d),
                "workout_volume": vol_rows.get(d, 0.0),
            })

        # also compute totals & averages
        totals = {"calories": sum(s["calories"] for s in series),
                  "protein_g": sum(s["protein_g"] for s in series),
                  "carbs_g": sum(s["carbs_g"] for s in series),
                  "fats_g": sum(s["fats_g"] for s in series)}
        avg = {k: (totals[k] / len(series) if series else 0) for k in totals}

        return {"start": start.isoformat(), "end": end.isoformat(), "series": series, "totals": totals, "average": avg}

    # --------------------------
    # Weekly / Monthly summaries
    # --------------------------
    def _completed_week_range(self, ref: date | None = None) -> tuple[date, date]:
        """
        Returns (monday, sunday) for the *last completed* week relative to ref (or today).
        Example: if today=Thu 2025-09-25, last completed week is Mon 2025-09-15 .. Sun 2025-09-21.
        """
        today = ref or date.today()
        # last completed week's sunday = yesterday - offset (weekday+1)
        last_sunday = today - timedelta(days=(today.weekday() + 1))
        last_monday = last_sunday - timedelta(days=6)
        return last_monday, last_sunday

    def _completed_month_range(self, ref: date | None = None) -> tuple[date, date]:
        """
        Return first_day, last_day for last completed month relative to ref (or today).
        """
        today = ref or date.today()
        first_this_month = date(today.year, today.month, 1)
        last_day_prev_month = first_this_month - timedelta(days=1)
        first_day_prev_month = date(last_day_prev_month.year, last_day_prev_month.month, 1)
        return first_day_prev_month, last_day_prev_month

    def get_weekly_summary(self, user_id: str, week_monday: date | None = None) -> dict[str, Any]:
        if week_monday is None:
            start, end = self._completed_week_range()
        else:
            start = week_monday
            end = start + timedelta(days=6)
        times = self.get_time_series(user_id, start, end)
        # Add simple week-level metrics (sum/avg)
        totals = times["totals"]
        return {"start": start.isoformat(), "end": end.isoformat(), "days": times["series"], "totals": totals, "average_per_day": times["average"]}

    def get_monthly_summary(self, user_id: str, month_start: date | None = None) -> dict[str, Any]:
        if month_start is None:
            start, end = self._completed_month_range()
        else:
            # if user passed a particular month_start, normalize to first day of that month
            start = date(month_start.year, month_start.month, 1)
            # compute last day of that month
            next_month = (start.replace(day=28) + timedelta(days=4)).replace(day=1)
            end = next_month - timedelta(days=1)
        times = self.get_time_series(user_id, start, end)
        return {"start": start.isoformat(), "end": end.isoformat(), "days": times["series"], "totals": times["totals"], "average_per_day": times["average"]}
