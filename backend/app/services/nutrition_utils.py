from datetime import date
from math import floor
from typing import Any, Tuple


def _safe_int(x, default=None):
    try:
        if x is None:
            return default
        return int(x)
    except Exception:
        return default

def _safe_float(x, default=None):
    try:
        if x is None:
            return default
        return float(x)
    except Exception:
        return default

def _lbs_to_kg(lbs: float | None) -> float | None:
    if lbs is None:
        return None
    try:
        return round(float(lbs) * 0.45359237, 2)
    except Exception:
        return None


def _ftin_to_cm(ft: int | None, inch: int | None) -> int | None:
    try:
        if ft is None and inch is None:
            return None
        total_inches = (int(ft) if ft else 0) * 12 + (int(inch) if inch else 0)
        cm = round(total_inches * 2.54)
        return int(cm)
    except Exception:
        return None


def _age_from_dob(dob: date | None) -> int | None:
    if not dob:
        return None
    today = date.today()
    age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return age

# constants
KCAL_PER_KG = 7700.0

def calculate_calories_and_macros(
    *,
    weight_kg: float | None,
    height_cm: int | None,
    age: int | None,
    gender: str | None,
    activity_level: str | None,
    goal_type: str | None,
    weekly_goal: float | None,
    macro_distribution: dict | None = None,
) -> Tuple[int, dict[str, int]]:
    """
    Returns (daily_calories, macro_targets)

    - weekly_goal: kg per week (positive -> gain, negative -> loss)
    """

    # Validate numeric inputs
    w = _safe_float(weight_kg)
    h = int(height_cm) if height_cm is not None else None
    a = int(age) if age is not None else None

    if w is None or h is None or a is None:
        raise ValueError("weight_kg, height_cm and age are required for calorie calculation")

    gen = (gender or "male").lower()

    # Mifflin-St Jeor
    if gen == "male":
        bmr = 10 * w + 6.25 * h - 5 * a + 5
    else:
        bmr = 10 * w + 6.25 * h - 5 * a - 161

    multipliers = {
        "sedentary": 1.2,
        "light": 1.375,
        "moderate": 1.55,
        "active": 1.725,
        "very_active": 1.9,
    }

    activity_key = (activity_level or "moderate").lower()
    multiplier = multipliers.get(activity_key, multipliers["moderate"])
    tdee = bmr * multiplier

    calories = tdee

    # FIXED: use weekly_goal directly (positive -> add calories, negative -> subtract)
    if weekly_goal is not None:
        try:
            weekly_goal_val = float(weekly_goal)
            # 1 kg change ≈ 7700 kcal. Apply weekly change converted to daily.
            calories += weekly_goal_val * KCAL_PER_KG / 7.0
        except Exception:
            pass
    else:
        # fallback: use goal_type if weekly_goal not provided
        if goal_type:
            g = (goal_type or "").lower()
            if g == "lose_weight":
                calories -= 500
            elif g == "gain_weight":
                calories += 300
            elif g == "maintain":
                pass

    calories = max(1200, round(calories))

    # Macro distribution
    md = macro_distribution or {}
    protein_pct = int(md.get("protein_pct", md.get("protein", 30)))
    carbs_pct = int(md.get("carbs_pct", md.get("carbs", 50)))
    fat_pct = int(md.get("fat_pct", md.get("fat", 20)))

    total_pct = protein_pct + carbs_pct + fat_pct
    if total_pct <= 0:
        protein_pct, carbs_pct, fat_pct = 30, 50, 20
        total_pct = 100

    if total_pct != 100:
        protein_pct = round(protein_pct * 100.0 / total_pct)
        carbs_pct = round(carbs_pct * 100.0 / total_pct)
        fat_pct = 100 - (protein_pct + carbs_pct)

    protein_g = floor((calories * protein_pct / 100.0) / 4.0)
    carbs_g = floor((calories * carbs_pct / 100.0) / 4.0)
    fats_g = floor((calories * fat_pct / 100.0) / 9.0)

    macro_targets = {
        "protein_g": int(protein_g),
        "carbs_g": int(carbs_g),
        "fats_g": int(fats_g),
        "protein_pct": protein_pct,
        "carbs_pct": carbs_pct,
        "fat_pct": fat_pct,
    }

    return int(calories), macro_targets

def compute_macros_for_calories(calories: int, macro_distribution: dict | None = None) -> dict[str, Any]:
    """
    Given a calories value and macro distribution (or defaults), return macro grams and percentages.
    """
    md = macro_distribution or {}
    protein_pct = int(md.get("protein_pct", md.get("protein", 30)))
    carbs_pct = int(md.get("carbs_pct", md.get("carbs", 50)))
    fat_pct = int(md.get("fat_pct", md.get("fat", 20)))

    total_pct = protein_pct + carbs_pct + fat_pct
    if total_pct <= 0:
        protein_pct, carbs_pct, fat_pct = 30, 50, 20
        total_pct = 100

    if total_pct != 100:
        protein_pct = round(protein_pct * 100.0 / total_pct)
        carbs_pct = round(carbs_pct * 100.0 / total_pct)
        fat_pct = 100 - (protein_pct + carbs_pct)

    protein_g = floor((calories * protein_pct / 100.0) / 4.0)
    carbs_g = floor((calories * carbs_pct / 100.0) / 4.0)
    fats_g = floor((calories * fat_pct / 100.0) / 9.0)

    return {
        "protein_g": int(protein_g),
        "carbs_g": int(carbs_g),
        "fats_g": int(fats_g),
        "protein_pct": protein_pct,
        "carbs_pct": carbs_pct,
        "fat_pct": fat_pct,
    }
