from datetime import date, datetime
from typing import Any
import uuid

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.models.sql_models import ExerciseEntry, WorkoutSession

def _generate_id() -> str:
    return uuid.uuid4().hex

def _calculate_total_volume(sets: list[dict[str, Any]] | None) -> float:
    """Compute sum(weight_kg * reps) across sets. Sets expected as [{weight_kg, reps}, ...]"""
    if not sets:
        return 0.0
    total = 0.0
    for s in sets:
        try:
            w = float(s.get("weight_kg", 0) or 0)
            r = int(s.get("reps", 0) or 0)
            total += w * r
        except Exception:
            continue
    return round(total, 2)

def _estimate_1rm(weight: float, reps: int) -> float:
    """Epley formula: 1RM = w * (1 + reps/30). For reps <= 0, return weight."""
    try:
        if reps <= 0:
            return float(weight)
        return round(weight * (1.0 + (reps / 30.0)), 2)
    except Exception:
        return float(weight)

def _validate_sets(sets: list[dict[str, Any]] | None) -> list[dict[str, Any]]:
    """Validate shape & values; raise ValueError on invalid data."""
    if sets is None:
        raise ValueError("sets must be provided and be a non-empty list")
    if not isinstance(sets, list) or len(sets) == 0:
        raise ValueError("sets must be a non-empty list")
    validated = []
    for i, s in enumerate(sets):
        if not isinstance(s, dict):
            raise ValueError(f"set at index {i} must be an object with weight_kg and reps")
        try:
            w = float(s.get("weight_kg", 0))
            r = int(s.get("reps", 0))
        except Exception:
            raise ValueError(f"invalid weight/reps at set index {i}")
        if w < 0:
            raise ValueError(f"weight_kg must be >= 0 at set index {i}")
        if r <= 0:
            raise ValueError(f"reps must be > 0 at set index {i}")
        # keep only expected keys to store
        new_s = {"weight_kg": round(w, 2), "reps": int(r)}
        # optional: store tempo, rest, notes inside set if provided
        for k in ("tempo", "rest_s", "notes"):
            if k in s:
                new_s[k] = s[k]
        validated.append(new_s)
    return validated

class WorkoutService:
    def __init__(self, db: Session):
        self.db = db

    # ---------- helpers ----------
    def _session_to_dict(self, s: WorkoutSession) -> dict[str, Any]:
        return {
            "session_id": s.session_id,
            "user_id": s.user_id,
            "date": s.date.isoformat(),
            "name": s.name,
            "notes": s.notes,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "updated_at": s.updated_at.isoformat() if s.updated_at else None,
        }

    def _exercise_to_dict(self, e: ExerciseEntry) -> dict[str, Any]:
        return {
            "entry_id": e.entry_id,
            "session_id": e.session_id,
            "user_id": e.user_id,
            "exercise_name": e.exercise_name,
            "sets": e.sets or [],
            "total_volume": float(e.total_volume) if e.total_volume is not None else None,
            "notes": e.notes,
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "updated_at": e.updated_at.isoformat() if e.updated_at else None,
        }

    # ---------- sessions CRUD ----------
    def create_session(self, user_id: str, session_date: date, name: str | None = None, notes: str | None = None) -> dict[str, Any]:
        session_id = _generate_id()
        s = WorkoutSession(session_id=session_id, user_id=user_id, date=session_date, name=name, notes=notes)
        self.db.add(s)
        self.db.commit()
        self.db.refresh(s)
        return self._session_to_dict(s)

    def list_sessions(self, user_id: str, start: date | None = None, end: date | None = None) -> list[dict[str, Any]]:
        q = self.db.query(WorkoutSession).filter(WorkoutSession.user_id == user_id)
        if start:
            q = q.filter(WorkoutSession.date >= start)
        if end:
            q = q.filter(WorkoutSession.date <= end)
        rows = q.order_by(WorkoutSession.date.desc()).all()
        return [self._session_to_dict(r) for r in rows]

    def get_session(self, session_id: str, user_id: str) -> dict[str, Any] | None:
        s = self.db.query(WorkoutSession).filter(WorkoutSession.session_id == session_id, WorkoutSession.user_id == user_id).first()
        return self._session_to_dict(s) if s else None

    def update_session(self, session_id: str, user_id: str, payload: dict) -> dict[str, Any] | None:
        s = self.db.query(WorkoutSession).filter(WorkoutSession.session_id == session_id, WorkoutSession.user_id == user_id).first()
        if not s:
            return None
        if "date" in payload:
            s.date = payload["date"]
        if "name" in payload:
            s.name = payload["name"]
        if "notes" in payload:
            s.notes = payload["notes"]
        s.updated_at = datetime.utcnow()
        self.db.add(s)
        self.db.commit()
        self.db.refresh(s)
        return self._session_to_dict(s)

    def delete_session(self, session_id: str, user_id: str) -> bool:
        s = self.db.query(WorkoutSession).filter(WorkoutSession.session_id == session_id, WorkoutSession.user_id == user_id).first()
        if not s:
            return False
        # delete exercises in this session first (cascade not assumed)
        self.db.query(ExerciseEntry).filter(ExerciseEntry.session_id == session_id).delete()
        self.db.delete(s)
        self.db.commit()
        return True

    # ---------- exercises CRUD ----------
    def add_exercise(self, session_id: str, user_id: str, payload: dict, commit: bool = True) -> dict[str, Any]:
        # validation: ensure session exists and belongs to user
        s = self.db.query(WorkoutSession).filter(WorkoutSession.session_id == session_id, WorkoutSession.user_id == user_id).first()
        if not s:
            raise ValueError("session not found")

        name = payload.get("exercise_name") or payload.get("name") or "Unknown"
        raw_sets = payload.get("sets")
        validated_sets = _validate_sets(raw_sets)
        total_volume = _calculate_total_volume(validated_sets)
        entry_id = _generate_id()
        ex = ExerciseEntry(
            entry_id=entry_id,
            session_id=session_id,
            user_id=user_id,
            exercise_name=name,
            sets=validated_sets,
            total_volume=total_volume,
            notes=payload.get("notes")
        )
        self.db.add(ex)
        if commit:
            try:
                self.db.commit()
                self.db.refresh(ex)
            except SQLAlchemyError:
                self.db.rollback()
                raise
        return self._exercise_to_dict(ex)

    def update_exercise(self, entry_id: str, user_id: str, payload: dict) -> dict[str, Any] | None:
        ex = self.db.query(ExerciseEntry).filter(ExerciseEntry.entry_id == entry_id, ExerciseEntry.user_id == user_id).first()
        if not ex:
            return None
        if "exercise_name" in payload:
            # ex.exercise_name = payload.get("exercise_name")
            ex.exercise_name = str(payload["exercise_name"])
        if "sets" in payload:
            validated = _validate_sets(payload.get("sets"))
            ex.sets = validated
            ex.total_volume = _calculate_total_volume(validated)
        if "notes" in payload:
            ex.notes = payload.get("notes")
        ex.updated_at = datetime.utcnow()
        self.db.add(ex)
        try:
            self.db.commit()
            self.db.refresh(ex)
        except SQLAlchemyError:
            self.db.rollback()
            raise
        return self._exercise_to_dict(ex)

    def delete_exercise(self, entry_id: str, user_id: str) -> bool:
        ex = self.db.query(ExerciseEntry).filter(ExerciseEntry.entry_id == entry_id, ExerciseEntry.user_id == user_id).first()
        if not ex:
            return False
        self.db.delete(ex)
        self.db.commit()
        return True

    def list_exercises_for_session(self, session_id: str, user_id: str) -> list[dict[str, Any]]:
        rows = self.db.query(ExerciseEntry).filter(ExerciseEntry.session_id == session_id, ExerciseEntry.user_id == user_id).order_by(ExerciseEntry.created_at.asc()).all()
        return [self._exercise_to_dict(r) for r in rows]

    # ---------- stats ----------
    def get_exercise_stats(self, user_id: str, exercise_name: str, start: date | None = None, end: date | None = None) -> dict[str, Any]:
        """
        Return overall totals + per-session breakdown + weekly & monthly trends + best set + estimated 1RM.
        """
        # query: join WorkoutSession -> ExerciseEntry (one join only)
        q = (
            self.db.query(
                WorkoutSession.date.label("session_date"),
                WorkoutSession.session_id.label("session_id"),
                ExerciseEntry.entry_id.label("entry_id"),
                ExerciseEntry.sets.label("sets"),
                ExerciseEntry.total_volume.label("total_volume"),
                ExerciseEntry.exercise_name.label("exercise_name"),
                ExerciseEntry.notes.label("notes")
            )
            .join(ExerciseEntry, ExerciseEntry.session_id == WorkoutSession.session_id)
            .filter(WorkoutSession.user_id == user_id)
            .filter(ExerciseEntry.exercise_name.ilike(f"%{exercise_name}%"))
        )

        if start:
            q = q.filter(WorkoutSession.date >= start)
        if end:
            q = q.filter(WorkoutSession.date <= end)

        rows = q.order_by(WorkoutSession.date.asc()).all()

        total_volume = 0.0
        total_reps = 0
        max_weight = 0.0
        sessions: dict[str, list] = {}  # session_id -> list of exercises (dict)
        best_set = None  # (weight, reps, 1rm, session_date, entry_id)

        # aggregated trends
        weekly_map: dict[str, dict[str, Any]] = {}
        monthly_map: dict[str, dict[str, Any]] = {}

        for r in rows:
            tv = float(r.total_volume or 0.0)
            total_volume += tv

            sets = r.sets or []
            entry_total_reps = 0
            # process sets for reps & best set
            for s in sets:
                try:
                    wt = float(s.get("weight_kg", 0) or 0)
                    reps = int(s.get("reps", 0) or 0)
                except Exception:
                    continue
                entry_total_reps += reps
                if wt > max_weight:
                    max_weight = wt
                # check best set by weight then reps then volume
                if best_set is None:
                    best_set = (wt, reps, _estimate_1rm(wt, reps), r.session_date.isoformat(), r.entry_id)
                else:
                    # prefer higher weight, tie-breaker higher reps
                    if wt > best_set[0] or (wt == best_set[0] and reps > best_set[1]):
                        best_set = (wt, reps, _estimate_1rm(wt, reps), r.session_date.isoformat(), r.entry_id)

            total_reps += entry_total_reps

            # append to sessions map keyed by session date for easier charting
            sessions.setdefault(r.session_date.isoformat(), []).append({
                "entry_id": r.entry_id,
                "exercise_name": r.exercise_name,
                "sets": sets,
                "total_volume": float(round(tv, 2)),
                "notes": r.notes
            })

            # weekly trend (ISO week)
            wk = r.session_date.isocalendar()  # (year, week, weekday)
            week_key = f"{wk[0]}-W{wk[1]:02d}"
            w = weekly_map.setdefault(week_key, {"period": week_key, "total_volume": 0.0, "max_weight": 0.0})
            w["total_volume"] += float(tv)
            if max_weight > w["max_weight"]:
                w["max_weight"] = max_weight

            # monthly trend
            mo_key = f"{r.session_date.year}-{r.session_date.month:02d}"
            m = monthly_map.setdefault(mo_key, {"period": mo_key, "total_volume": 0.0, "max_weight":0.0})
            m["total_volume"] += float(tv)
            if max_weight > m["max_weight"]:
                m["max_weight"] = max_weight

        # prepare trends sorted
        weekly_trend = sorted(weekly_map.values(), key=lambda x: x["period"])
        monthly_trend = sorted(monthly_map.values(), key=lambda x: x["period"])

        return {
            "exercise_name": exercise_name,
            "sessions_count": sum(len(v) for v in sessions.values()),
            "total_volume": float(round(total_volume, 2)),
            "total_reps": int(total_reps),
            "max_weight_kg": float(round(max_weight, 2)),
            "best_set": {
                "weight_kg": best_set[0],
                "reps": best_set[1],
                "estimated_1rm": best_set[2],
                "session_date": best_set[3],
                "entry_id": best_set[4],
            } if best_set else None,
            "sessions": sessions,
            "weekly_trend": weekly_trend,
            "monthly_trend": monthly_trend,
        }

