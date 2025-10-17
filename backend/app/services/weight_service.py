from datetime import date, datetime
from typing import Any
import uuid

from sqlalchemy.orm import Session

from app.models.sql_models import User, WeightEntry
from app.services.nutrition_utils import calculate_calories_and_macros

def _generate_id() -> str:
    return uuid.uuid4().hex

# safety caps for adjustments
MAX_DAILY_ADJUSTMENT_ABS = 1000  # max ±1000 kcal/day added/removed by the algorithm

class WeightService:
    def __init__(self, db: Session):
        self.db = db

    def _to_dict(self, e: WeightEntry) -> dict[str, Any]:
        return {
            "entry_id": e.entry_id,
            "user_id": e.user_id,
            "date": e.date.isoformat(),
            "weight_kg": float(e.weight_kg) if e.weight_kg is not None else None,
            "note": e.note,
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "updated_at": e.updated_at.isoformat() if e.updated_at else None,
        }

    def add_entry(self, user_id: str, entry_date: date, weight_kg: float, note: str | None = None) -> dict[str, Any]:
        """Create a new weight entry and compute a metabolic adjustment based on last entry."""
        entry_id = _generate_id()
        entry = WeightEntry(
            entry_id=entry_id,
            user_id=user_id,
            date=entry_date,
            weight_kg=float(weight_kg),
            note=note,
        )
        self.db.add(entry)
        self.db.commit()
        self.db.refresh(entry)

        # compute adjustment (updates user.onboarding_summary.metabolic_adjustment_kcal)
        adj_info = self._compute_adjustment_after_entry(user_id, entry)

        return {"entry": self._to_dict(entry), "adjustment": adj_info}

    def list_entries(self, user_id: str, start: date | None = None, end: date | None = None) -> list[dict[str, Any]]:
        q = self.db.query(WeightEntry).filter(WeightEntry.user_id == user_id)
        if start:
            q = q.filter(WeightEntry.date >= start)
        if end:
            q = q.filter(WeightEntry.date <= end)

        rows = q.order_by(WeightEntry.date.desc()).all()
        return [self._to_dict(r) for r in rows]

    def get_entry(self, entry_id: str, user_id: str) -> dict[str, Any] | None:
        r = self.db.query(WeightEntry).filter(WeightEntry.entry_id == entry_id, WeightEntry.user_id == user_id).first()
        return self._to_dict(r) if r else None

    def delete_entry(self, entry_id: str, user_id: str) -> bool:
        r = self.db.query(WeightEntry).filter(WeightEntry.entry_id == entry_id, WeightEntry.user_id == user_id).first()
        if not r:
            return False
        self.db.delete(r)
        self.db.commit()

        # after deletion, recompute adjustment from last two entries (best-effort)
        self._recompute_adjustment_from_latest(user_id)
        return True

    def _compute_adjustment_after_entry(self, user_id: str, new_entry: WeightEntry) -> dict[str, Any]:
        """
        Compare the new entry with the previous-most recent entry and user weekly goal,
        compute daily kcal delta to steer progress back to the user's chosen rate.
        Save the cumulative adjustment into user.onboarding_summary['metabolic_adjustment_kcal'].
        Returns info about the adjustment.
        """

        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            return {"ok": False, "reason": "user_not_found"}

        summary = user.onboarding_summary or {}
        weekly_goal = summary.get("weekly_goal")

        prev = (
            self.db.query(WeightEntry)
            .filter(WeightEntry.user_id == user_id, WeightEntry.date < new_entry.date)
            .order_by(WeightEntry.date.desc())
            .first()
        )

        if prev:
            days = (new_entry.date - prev.date).days
            if days <= 0:
                days = 1
            prev_w = float(prev.weight_kg)
            new_w = float(new_entry.weight_kg)
            actual_change = new_w - prev_w
            expected_change = 0.0
            if weekly_goal is not None:
                try:
                    expected_change = float(weekly_goal) * (days / 7.0)
                except Exception:
                    expected_change = 0.0

            discrepancy = actual_change - expected_change
            # convert discrepancy to total kcal difference (1 kg ~ 7700 kcal)
            kcal_total_needed = - discrepancy * 7700.0
            # convert to daily delta to apply for the remaining period (spread over days)
            daily_delta = kcal_total_needed / max(days, 1)

            # clamp daily_delta to reasonable bounds
            daily_delta = max(-MAX_DAILY_ADJUSTMENT_ABS, min(MAX_DAILY_ADJUSTMENT_ABS, daily_delta))

            # accumulate into onboarding summary
            curr_adj = summary.get("metabolic_adjustment_kcal", 0) or 0
            new_adj = curr_adj + daily_delta
            # clamp total accumulated adj to reasonable bounds too
            new_adj = max(-MAX_DAILY_ADJUSTMENT_ABS, min(MAX_DAILY_ADJUSTMENT_ABS, new_adj))

            summary["metabolic_adjustment_kcal"] = float(round(new_adj, 1))
            # persist changes
            user.onboarding_summary = summary
            user.updated_at = datetime.utcnow()
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)

            # recompute daily calories using current nutrition logic (best-effort)
            try:
                base_cal, base_macros = calculate_calories_and_macros(
                    weight_kg=summary.get("starting_weight_kg") or new_entry.weight_kg,
                    height_cm=user.height_cm,
                    age=summary.get("age"),
                    gender=summary.get("gender") or user.gender,
                    activity_level=(user.preferences or {}).get("lifestyle", {}).get("activity_level"),
                    goal_type=user.goal,
                    weekly_goal=summary.get("weekly_goal"),
                    macro_distribution=(user.preferences or {}).get("macro_distribution")
                )
                adjusted_calories = int(max(1200, round(base_cal + summary.get("metabolic_adjustment_kcal", 0))))
            except Exception:
                base_cal = None
                base_macros = None
                adjusted_calories = None

            return {
                "ok": True,
                "days": days,
                "previous_weight": prev_w,
                "new_weight": new_w,
                "actual_change": actual_change,
                "expected_change": expected_change,
                "discrepancy_kg": discrepancy,
                "daily_delta_kcal_applied": float(round(daily_delta, 1)),
                "cumulative_metabolic_adjustment_kcal": summary.get("metabolic_adjustment_kcal"),
                "adjusted_calories_estimate": adjusted_calories,
            }

        else:
            # no previous entry -> use baseline starting weight if present; if not, nothing to compute
            baseline = summary.get("starting_weight_kg")
            if baseline is None:
                return {"ok": True, "reason": "no_prev_entry_no_baseline"}
            # if baseline exists, compute days since baseline? can't reliably compute without baseline date.
            return {"ok": True, "reason": "no_prev_entry_but_baseline_exists"}

    def _recompute_adjustment_from_latest(self, user_id: str):
        """Simple recompute: take last two entries (if present) and recompute the adjustment similarly."""
        last_two = (
            self.db.query(WeightEntry)
            .filter(WeightEntry.user_id == user_id)
            .order_by(WeightEntry.date.desc())
            .limit(2)
            .all()
        )
        if len(last_two) < 2:
            # no change possible — reset adjustment
            user = self.db.query(User).filter(User.user_id == user_id).first()
            if user:
                summary = user.onboarding_summary or {}
                summary["metabolic_adjustment_kcal"] = 0.0
                user.onboarding_summary = summary
                self.db.add(user)
                self.db.commit()
            return {"ok": True, "reason": "not_enough_entries_reset_adj"}

        # recompute using most recent 2 entries
        newer, older = last_two[0], last_two[1]
        return self._compute_adjustment_after_entry(user_id, newer)
