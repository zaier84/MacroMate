from datetime import date, timedelta
import math
from typing import Any
from sqlalchemy.orm import Session
import uuid
import logging

from app.models.sql_models import Recipe, MealPlan, User
from app.services.food_service import FoodAPIClient
from app.services.food_log_service import FoodLogService
from app.services.nutrition_utils import calculate_calories_and_macros  # use your util

logger = logging.getLogger(__name__)

def _generate_id() -> str:
    return uuid.uuid4().hex

class MealService:
    def __init__(self, db: Session):
        self.db = db
        self.food_api = FoodAPIClient()
        # we will use FoodLogService when accepting planned meal
        self.food_log = FoodLogService(db)

    # ---------- Recipe CRUD ----------
    def create_recipe(self, user_id: str, payload: dict[str, Any]) -> dict[str, Any]:
        """
        payload: {
            title, description, servings, ingredients: [ {food_api_id?, name, quantity, unit, calories?, protein_g?, carbs_g?, fats_g?, raw?} ]
        }
        Tries to compute nutrition for the recipe by fetching provider details for each ingredient when possible.
        """
        title = payload.get("title") or "Untitled"
        servings = float(payload.get("servings") or 1.0)
        description = payload.get("description")
        ingredients = payload.get("ingredients") or []
        computed = {"calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fats_g": 0.0}
        ingredient_records = []

        for ing in ingredients:
            rec = dict(ing)
            # allow client-provided nutrition values
            cal = rec.get("calories")
            prot = rec.get("protein_g")
            carbs = rec.get("carbs_g")
            fats = rec.get("fats_g")

            # if missing nutrition but food_api_id present, try fetching
            if (cal is None or prot is None or carbs is None or fats is None) and rec.get("food_api_id"):
                try:
                    details = self.food_api.get_details(rec["food_api_id"])
                    # try to extract calories/protein/carbs/fats in flexible ways
                    # support several possible keys
                    # prefer per 100g scaling if provided
                    # details may contain:
                    # - calories_per_100g OR calories (per 100g or per serving) OR energy_kcal etc.
                    # - protein_g, carbs_g, fats_g
                    qty = rec.get("quantity")
                    unit = (rec.get("unit") or "").lower()
                    # helper to grab numeric
                    def _num(key):
                        v = details.get(key)
                        if v is None:
                            return None
                        try:
                            return float(v)
                        except Exception:
                            return None

                    # identify whether details have per_100g fields
                    per100_cal = _num("calories_per_100g") or _num("energy_kcal_per_100g")
                    per100_prot = _num("protein_per_100g") or _num("protein_g_per_100g") or _num("protein_g")
                    per100_carbs = _num("carbs_per_100g") or _num("carbs_g_per_100g") or _num("carbs_g")
                    per100_fats = _num("fat_per_100g") or _num("fats_per_100g") or _num("fat_g")

                    # fallback direct keys
                    direct_cal = _num("calories") or _num("energy_kcal")
                    direct_prot = _num("protein_g") or _num("protein")
                    direct_carbs = _num("carbs_g") or _num("carbs")
                    direct_fats = _num("fats_g") or _num("fat")

                    if per100_cal and qty and str(unit).startswith("g"):
                        factor = float(qty) / 100.0
                        cal = cal if cal is not None else per100_cal * factor
                        prot = prot if prot is not None else (per100_prot * factor if per100_prot else None)
                        carbs = carbs if carbs is not None else (per100_carbs * factor if per100_carbs else None)
                        fats = fats if fats is not None else (per100_fats * factor if per100_fats else None)
                    elif direct_cal is not None:
                        # assume direct_cal corresponds to the provided qty (common when API returns serving data)
                        cal = cal if cal is not None else direct_cal
                        prot = prot if prot is not None else direct_prot
                        carbs = carbs if carbs is not None else direct_carbs
                        fats = fats if fats is not None else direct_fats
                    else:
                        # if still missing, try best-effort per-100 fallback with unknown unit -> assume qty grams
                        try:
                            if per100_cal and qty:
                                factor = float(qty) / 100.0
                                cal = cal if cal is not None else per100_cal * factor
                                prot = prot if prot is not None else (per100_prot * factor if per100_prot else None)
                                carbs = carbs if carbs is not None else (per100_carbs * factor if per100_carbs else None)
                                fats = fats if fats is not None else (per100_fats * factor if per100_fats else None)
                        except Exception:
                            pass

                    # store raw details for audit
                    rec["raw"] = details
                except Exception:
                    logger.exception("Food API details fetch failed for %s", rec.get("food_api_id"))
                    # proceed with partial info if any

            # accumulate computed nutrition if we have numeric values
            try:
                if cal is not None:
                    computed["calories"] += float(cal)
                if prot is not None:
                    computed["protein_g"] += float(prot)
                if carbs is not None:
                    computed["carbs_g"] += float(carbs)
                if fats is not None:
                    computed["fats_g"] += float(fats)
            except Exception:
                pass

            ingredient_records.append(rec)

        # compute final nutrition dict; treat computed as whole recipe
        nutrition = {
            "calories": int(round(computed["calories"])) if computed["calories"] else None,
            "protein_g": float(round(computed["protein_g"], 1)) if computed["protein_g"] else None,
            "carbs_g": float(round(computed["carbs_g"], 1)) if computed["carbs_g"] else None,
            "fats_g": float(round(computed["fats_g"], 1)) if computed["fats_g"] else None,
            "per_serving": None
        }
        if nutrition["calories"] is not None:
            try:
                nutrition["per_serving"] = {
                    "calories": int(round(nutrition["calories"] / max(1.0, servings))),
                    "protein_g": float(round((nutrition["protein_g"] or 0.0) / max(1.0, servings), 1)),
                    "carbs_g": float(round((nutrition["carbs_g"] or 0.0) / max(1.0, servings), 1)),
                    "fats_g": float(round((nutrition["fats_g"] or 0.0) / max(1.0, servings), 1)),
                }
            except Exception:
                nutrition["per_serving"] = None

        # persist
        recipe = Recipe(
            recipe_id=_generate_id(),
            user_id=user_id,
            title=title,
            description=description,
            servings=servings,
            ingredients=ingredient_records,
            nutrition=nutrition
        )
        self.db.add(recipe)
        self.db.commit()
        self.db.refresh(recipe)
        return self._to_dict(recipe)

    def list_recipes(self, user_id: str) -> list[dict]:
        rows = self.db.query(Recipe).filter(Recipe.user_id == user_id).order_by(Recipe.title.asc()).all()
        return [self._to_dict(r) for r in rows]

    def get_recipe(self, recipe_id: str, user_id: str) -> dict | None:
        r = self.db.query(Recipe).filter(Recipe.recipe_id == recipe_id, Recipe.user_id == user_id).first()
        return self._to_dict(r) if r else None

    def delete_recipe(self, recipe_id: str, user_id: str) -> bool:
        r = self.db.query(Recipe).filter(Recipe.recipe_id == recipe_id, Recipe.user_id == user_id).first()
        if not r:
            return False
        self.db.delete(r)
        self.db.commit()
        return True

    def _to_dict(self, r: Recipe) -> dict:
        return {
            "recipe_id": r.recipe_id,
            "user_id": r.user_id,
            "title": r.title,
            "description": r.description,
            "servings": float(r.servings),
            "ingredients": r.ingredients,
            "nutrition": r.nutrition,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "updated_at": r.updated_at.isoformat() if r.updated_at else None,
        }

    # ---------- MealPlan generation & management ----------
    def generate_plan(self, user_id: str, start_date: date, days: int = 3, meals: list[str] | None = None, tolerance_pct: int = 10) -> dict:
        """
        Simple deterministic generator:
        - pulls user's recipes first; if none, falls back to 'single-item' candidate list from Food API
        - aims to match daily target calories from onboarding_summary
        - distributes target across 'meals' equally (naive)
        Returns a plan object (not persisted).
        """
        if meals is None or len(meals) == 0:
            meals = ["breakfast", "lunch", "dinner"]

        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise ValueError("User not found")

        summary = dict(user.onboarding_summary or {})
        prefs = dict(user.preferences or {})
        # daily target calories
        daily_target = summary.get("daily_calories")
        if daily_target is None:
            # compute on the fly using calc util
            try:
                daily_target, _ = calculate_calories_and_macros(
                    weight_kg=summary.get("starting_weight_kg"),
                    height_cm=user.height_cm,
                    age=summary.get("age"),
                    gender=summary.get("gender") or user.gender,
                    activity_level=(prefs.get("lifestyle") or {}).get("activity_level"),
                    goal_type=user.goal,
                    weekly_goal=summary.get("weekly_goal"),
                    macro_distribution=(prefs.get("macro_distribution"))
                )
            except Exception as e:
                raise ValueError("Cannot compute target calories: " + str(e))

        # collection of candidate items (recipes + quick foods)
        recipes = self.db.query(Recipe).filter(Recipe.user_id == user_id).all()
        candidates = []
        for r in recipes:
            nut = r.nutrition or {}
            per_serv = (nut.get("per_serving") or {})
            candidates.append({
                "type": "recipe",
                "recipe_id": r.recipe_id,
                "title": r.title,
                "calories": per_serv.get("calories") if per_serv else nut.get("calories"),
                "nutrition": per_serv or nut.get("per_serving") or nut
            })

        # if no recipes found, add a small set of staples by querying food API
        if not candidates:
            staples = ["egg", "chicken breast", "rice", "banana", "oats"]
            for s in staples:
                try:
                    res = self.food_api.search(s, page=1, page_size=1)
                    if res and res.get("results"):
                        f = res["results"][0]
                        details = self.food_api.get_details(f.get("id") or f.get("fdcId") or f.get("food_api_id"))
                        # if details contain calories assume per item/serving
                        cal = details.get("calories") or details.get("energy_kcal") or details.get("calories_per_100g")
                        candidates.append({
                            "type": "food",
                            "food_api_id": f.get("id") or f.get("fdcId"),
                            "title": f.get("description") or f.get("name") or s,
                            "calories": float(cal) if cal else None,
                            "nutrition": details
                        })
                except Exception:
                    continue

        # naive greedy: for each day choose meals_count items from candidates that approximate daily target.
        plan_days = {}
        per_meal_target = float(daily_target) / max(1, len(meals))
        for d in range(days):
            day_dt = start_date + timedelta(days=d)
            iso = day_dt.isoformat()
            plan_days[iso] = []
            for meal_type in meals:
                # find candidate whose calories close to per_meal_target
                best = None
                best_diff = math.inf
                for c in candidates:
                    c_cal = c.get("calories") or 0
                    if c_cal is None:
                        continue
                    diff = abs(c_cal - per_meal_target)
                    if best is None or diff < best_diff:
                        best = c
                        best_diff = diff
                if best is None:
                    # fallback - empty meal
                    entry = {"meal_type": meal_type, "title": None, "calories": None, "items": []}
                else:
                    entry = {
                        "meal_type": meal_type,
                        "title": best.get("title"),
                        "calories": int(round(best.get("calories") or 0)),
                        "recipe_id": best.get("recipe_id") if best.get("type") == "recipe" else None,
                        "items": [best] if best.get("type") == "food" else [],
                        "nutrition": best.get("nutrition")
                    }
                plan_days[iso].append(entry)

        plan = {
            "plan_id": _generate_id(),
            "user_id": user_id,
            "start_date": start_date.isoformat(),
            "end_date": (start_date + timedelta(days=days-1)).isoformat(),
            "days": plan_days,
        }
        return plan

    def save_plan(self, user_id: str, plan_obj: dict) -> dict:
        p = MealPlan(
            plan_id=plan_obj.get("plan_id") or _generate_id(),
            user_id=user_id,
            start_date=plan_obj["start_date"],
            end_date=plan_obj["end_date"],
            days=plan_obj["days"]
        )
        self.db.add(p)
        self.db.commit()
        self.db.refresh(p)
        return self._plan_to_dict(p)

    def get_plans(self, user_id: str, start: date | None = None, end: date | None = None) -> list[dict]:
        q = self.db.query(MealPlan).filter(MealPlan.user_id == user_id)
        if start:
            q = q.filter(MealPlan.start_date >= start)
        if end:
            q = q.filter(MealPlan.end_date <= end)
        rows = q.order_by(MealPlan.start_date.desc()).all()
        return [self._plan_to_dict(r) for r in rows]

    def get_plan(self, plan_id: str, user_id: str) -> dict | None:
        r = self.db.query(MealPlan).filter(MealPlan.plan_id == plan_id, MealPlan.user_id == user_id).first()
        return self._plan_to_dict(r) if r else None

    def delete_plan(self, plan_id: str, user_id: str) -> bool:
        r = self.db.query(MealPlan).filter(MealPlan.plan_id == plan_id, MealPlan.user_id == user_id).first()
        if not r:
            return False
        self.db.delete(r)
        self.db.commit()
        return True

    # Accept a planned meal -> create FoodEntry(s) via FoodLogService.add_food_entries
    def accept_meal(self, user_id: str, plan_id: str, iso_date: str, meal_type: str, items: list[dict] | None = None) -> dict:
        """
        items: optional override list of food dicts compatible with FoodLogService.add_food_entries
        If recipe present in plan day, expands recipe ingredients to food items (attempting to use food_api_id)
        """
        plan = self.get_plan(plan_id, user_id)
        if not plan:
            raise ValueError("Plan not found")

        day_obj = plan["days"].get(iso_date)
        if not day_obj:
            raise ValueError("Date not in plan")

        # find the meal entry
        entry = next((m for m in day_obj if m.get("meal_type") == meal_type), None)
        if not entry:
            raise ValueError("Meal not found")

        foods_to_log = []
        # if items provided by client, use them
        if items:
            foods_to_log = items
        elif entry.get("recipe_id"):
            recipe = self.get_recipe(entry["recipe_id"], user_id)
            if recipe:
                # convert recipe ingredients to food-log items (assume ingredient quantity & unit)
                for ing in recipe["ingredients"]:
                    foods_to_log.append({
                        "food_api_id": ing.get("food_api_id"),
                        "name": ing.get("name"),
                        "brand": ing.get("brand") if ing.get("brand") else None,
                        "quantity": ing.get("quantity"),
                        "unit": ing.get("unit"),
                        "calories": ing.get("calories"),
                        "protein_g": ing.get("protein_g"),
                        "carbs_g": ing.get("carbs_g"),
                        "fats_g": ing.get("fats_g"),
                        "raw": ing.get("raw")
                    })
        else:
            # fallback: if entry had items list (from generate_plan) use them
            for it in entry.get("items", []):
                foods_to_log.append({
                    "food_api_id": it.get("food_api_id"),
                    "name": it.get("title") or it.get("description"),
                    "quantity": it.get("quantity") or 1,
                    "unit": it.get("unit") or None,
                    "calories": it.get("calories"),
                    "protein_g": it.get("protein_g"),
                    "carbs_g": it.get("carbs_g"),
                    "fats_g": it.get("fats_g"),
                    "raw": it.get("nutrition") or it.get("raw")
                })

        # call FoodLogService.add_food_entries -> date object
        day_date = date.fromisoformat(iso_date)
        created = self.food_log.add_food_entries(user_id=user_id, day=day_date, meal_type=meal_type, foods=foods_to_log)
        return {"ok": True, "created": created}

    def shopping_list(self, user_id: str, plan_id: str) -> dict:
        plan = self.get_plan(plan_id, user_id)
        if not plan:
            raise ValueError("Plan not found")
        agg = {}
        for iso, meals in plan["days"].items():
            for m in meals:
                # if recipe_id present, fetch recipe ingredients
                if m.get("recipe_id"):
                    r = self.get_recipe(m["recipe_id"], user_id)
                    if not r:
                        continue
                    for ing in r["ingredients"]:
                        key = (ing.get("name") or "").lower()
                        qty = float(ing.get("quantity") or 0)
                        unit = ing.get("unit") or ""
                        k = (key, unit)
                        agg.setdefault(k, 0.0)
                        agg[k] += qty
                else:
                    # items list
                    for it in m.get("items", []):
                        key = (it.get("title") or "").lower()
                        qty = float(it.get("quantity") or 1)
                        unit = it.get("unit") or ""
                        k = (key, unit)
                        agg.setdefault(k, 0.0)
                        agg[k] += qty

        # format
        out = []
        for (name, unit), qty in agg.items():
            out.append({"name": name, "unit": unit, "quantity": float(round(qty, 2))})
        return {"plan_id": plan_id, "shopping_list": out}

    def _plan_to_dict(self, p: MealPlan) -> dict:
        return {
            "plan_id": p.plan_id,
            "user_id": p.user_id,
            "start_date": p.start_date.isoformat(),
            "end_date": p.end_date.isoformat(),
            "days": p.days,
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "updated_at": p.updated_at.isoformat() if p.updated_at else None,
        }
