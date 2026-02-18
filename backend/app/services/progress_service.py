from datetime import date, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from calendar import monthrange

from app.models.sql_models import User, WeightEntry, FoodEntry


class ProgressService:
    def __init__(self, db: Session):
        self.db = db

    def get_monthly_progress(self, user_id: str, year: int, month: int):
        start_date = date(year, month, 1)
        end_date = date(year, month, monthrange(year, month)[1])

        # ─────────────────────────────
        # Weight entries (monthly)
        # ─────────────────────────────
        weight_entries = (
            self.db.query(WeightEntry)
            .filter(
                WeightEntry.user_id == user_id,
                WeightEntry.date >= start_date,
                WeightEntry.date <= end_date,
            )
            .order_by(WeightEntry.date.asc())
            .all()
        )

        if not weight_entries:
            current_weight = None
            last_week_weight = None
            weight_trend = []
        else:
            weight_trend = [
                {
                    "date": w.date.isoformat(),
                    "weight": float(w.weight_kg),
                }
                for w in weight_entries
            ]

            current_weight = weight_entries[-1].weight_kg

            one_week_ago = weight_entries[-1].date - timedelta(days=7)

            last_week_entry = (
                self.db.query(WeightEntry)
                .filter(
                    WeightEntry.user_id == user_id,
                    WeightEntry.date <= one_week_ago,
                )
                .order_by(WeightEntry.date.desc())
                .first()
            )

            last_week_weight = (
                last_week_entry.weight_kg if last_week_entry else None
            )

        # ─────────────────────────────
        # Average calories
        # ─────────────────────────────
        avg_calories = (
            self.db.query(func.avg(FoodEntry.calories))
            .filter(
                FoodEntry.user_id == user_id,
                FoodEntry.date >= start_date,
                FoodEntry.date <= end_date,
            )
            .scalar()
        )

        avg_calories = int(avg_calories) if avg_calories else 0

        # ─────────────────────────────
        # User info (BMI & goals)
        # ─────────────────────────────
        user = self.db.query(User).filter(User.user_id == user_id).first()

        bmi = None
        if user and user.height_cm and current_weight:
            height_m = user.height_cm / 100
            bmi = round(current_weight / (height_m ** 2), 1)

        target_weight = None
        remaining = None
        if user and user.onboarding_summary:
            target_weight = user.onboarding_summary.get("target_weight_kg")
            if target_weight and current_weight:
                remaining = round(target_weight - current_weight, 1)

        # ─────────────────────────────
        # Weight change & trend
        # ─────────────────────────────
        weight_change = None
        direction = "stable"

        if current_weight is not None and last_week_weight is not None:
            diff = round(current_weight - last_week_weight, 1)
            weight_change = diff
            if diff < 0:
                direction = "down"
            elif diff > 0:
                direction = "up"

        trend = (
            "losing" if direction == "down"
            else "gaining" if direction == "up"
            else "stable"
        )

        return {
            "month": start_date.strftime("%B %Y"),
            "metrics": {
                "currentWeight": current_weight,
                "lastWeekWeight": last_week_weight,
                "averageCalories": avg_calories,
                "bmi": bmi,
            },
            "weightChange": {
                "value": weight_change,
                "direction": direction,
            },
            "weightTrend": weight_trend,
            "units": {
                "weight": "kg",
                "calories": "kcal",
            },
            "trend": trend,
            "goal": {
                "targetWeight": target_weight,
                "remaining": remaining,
            },
        }



# from datetime import date, datetime, timedelta
# from sqlalchemy.orm import Session
# from sqlalchemy import func
# from calendar import monthrange
#
# from app.models.sql_models import User, WeightEntry, FoodEntry
#
# class ProgressService:
#     def __init__(self, db: Session):
#         self.db = db
#
#     def get_monthly_progress(self, user_id: str, year: int, month: int):
#         start_date = date(year, month, 1)
#         end_date = date(year, month, monthrange(year, month)[1])
#
#         # ─────────────────────────────
#         # Weight logs (monthly)
#         # ─────────────────────────────
#         weight_logs = (
#             self.db.query(WeightEntry)
#             .filter(
#                 WeightEntry.user_id == user_id,
#                 WeightEntry.logged_at >= start_date,
#                 WeightEntry.logged_at <= end_date,
#             )
#             .order_by(WeightEntry.logged_at.asc())
#             .all()
#         )
#
#         if not weight_logs:
#             current_weight = None
#             last_week_weight = None
#             weight_trend = []
#         else:
#             weight_trend = [
#                 {
#                     "date": w.logged_at.date().isoformat(),
#                     "weight": float(w.weight_kg),
#                 }
#                 for w in weight_logs
#             ]
#
#             current_weight = weight_logs[-1].weight_kg
#
#             one_week_ago = weight_logs[-1].logged_at - timedelta(days=7)
#             last_week_entry = (
#                 self.db.query(WeightEntry)
#                 .filter(
#                     WeightEntry.user_id == user_id,
#                     WeightEntry.logged_at <= one_week_ago,
#                 )
#                 .order_by(WeightEntry.logged_at.desc())
#                 .first()
#             )
#             last_week_weight = (
#                 last_week_entry.weight_kg if last_week_entry else None
#             )
#
#         # ─────────────────────────────
#         # Average calories
#         # ─────────────────────────────
#         avg_calories = (
#             self.db.query(func.avg(FoodEntry.calories))
#             .filter(
#                 FoodEntry.user_id == user_id,
#                 FoodEntry.logged_at >= start_date,
#                 FoodEntry.logged_at <= end_date,
#             )
#             .scalar()
#         )
#
#         avg_calories = int(avg_calories) if avg_calories else 0
#
#         # ─────────────────────────────
#         # User info (BMI & goals)
#         # ─────────────────────────────
#         user = self.db.query(User).filter(User.user_id == user_id).first()
#
#         bmi = None
#         if user and user.height_cm and current_weight:
#             height_m = user.height_cm / 100
#             bmi = round(current_weight / (height_m ** 2), 1)
#
#         target_weight = None
#         remaining = None
#         if user and user.onboarding_summary:
#             target_weight = user.onboarding_summary.get("target_weight_kg")
#             if target_weight and current_weight:
#                 remaining = round(target_weight - current_weight, 1)
#
#         # ─────────────────────────────
#         # Weight change & trend
#         # ─────────────────────────────
#         weight_change = None
#         direction = "stable"
#
#         if current_weight and last_week_weight:
#             diff = round(current_weight - last_week_weight, 1)
#             weight_change = diff
#             if diff < 0:
#                 direction = "down"
#             elif diff > 0:
#                 direction = "up"
#
#         trend = (
#             "losing" if direction == "down"
#             else "gaining" if direction == "up"
#             else "stable"
#         )
#
#         return {
#             "month": start_date.strftime("%B %Y"),
#             "metrics": {
#                 "currentWeight": current_weight,
#                 "lastWeekWeight": last_week_weight,
#                 "averageCalories": avg_calories,
#                 "bmi": bmi,
#             },
#             "weightChange": {
#                 "value": weight_change,
#                 "direction": direction,
#             },
#             "weightTrend": weight_trend,
#             "units": {
#                 "weight": "kg",
#                 "calories": "kcal",
#             },
#             "trend": trend,
#             "goal": {
#                 "targetWeight": target_weight,
#                 "remaining": remaining,
#             },
#         }
#
