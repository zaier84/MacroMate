from google import genai
import json
import uuid
from datetime import date, timedelta

from datetime import timedelta

from sqlalchemy.orm import Session

from app.models.sql_models import MealPlan

def map_days_to_dates(start_date: date, ai_days: dict) -> dict:
    mapped = {}
    for i, (_, meals) in enumerate(ai_days.items()):
        day_date = start_date + timedelta(days=i)
        mapped[day_date.isoformat()] = meals
    return mapped

class GeminiMealPlanner:
    def __init__(self, api_key: str, model: str = "gemini-2.5-flash"):
        self.client = genai.Client(api_key=api_key)
        self.model = model

    def call_gemini(self, prompt: str, max_retries: int = 3) -> dict:
        """Send structured prompt to Gemini and parse JSON safely."""
        last_error = None

        for attempt in range(max_retries):
            try:
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=prompt
                )
                # text = response.text.strip()
                if not response.candidates or not response.candidates[0].content:
                    raise ValueError("Gemini returned no content")

                content_obj = response.candidates[0].content
                text = str(content_obj).strip()

                # Ensure only JSON is returned
                first_brace = text.find("{")
                last_brace = text.rfind("}")
                json_str = text[first_brace:last_brace + 1]

                return json.loads(json_str)

            except Exception as e:
                last_error = e

        raise Exception(f"Gemini request failed after {max_retries} attempts: {last_error}")

    def build_prompt(self, user_profile: dict, days: int,
                     target_calories: float, macros: dict) -> str:

        restrictions = ", ".join(user_profile.get("dietary_restrictions", [])) or "none"
        allergies = ", ".join(user_profile.get("allergies", [])) or "none"
        cuisines = ", ".join(user_profile.get("cuisine_preferences", [])) or "any"
        meals_per_day = ", ".join(user_profile.get("meals_per_day", [])) or "breakfast, lunch, dinner"

        return f"""
            You are a professional nutritionist AI. 
            Generate a STRICTLY VALID JSON meal plan for **{days} day(s)** ONLY.
            The JSON must be easy to parse and must never contain comments or trailing commas.

            === USER PROFILE ===
            Goal: {user_profile['goal']}
            Meals per day: {meals_per_day}
            Calories per day: {int(target_calories)}
            Daily Macros:
            - Protein: {int(macros['protein'])}g
            - Carbs: {int(macros['carbs'])}g
            - Fats: {int(macros['fats'])}g

            Dietary Restrictions: {restrictions}
            Allergies: {allergies}
            Cuisine Preferences: {cuisines}

            === RULES ===
            - Return ONLY VALID JSON — no explanations.
            - Each meal must include: name, calories, protein, carbs, fats.
            - Total calories per day must equal {int(target_calories)} ±5%.
            - Total macros per day must equal targets ±5%.
            - Distribute calories across meals reasonably:
                Breakfast ~25%, Lunch ~35%, Dinner ~40%.
            - Avoid restricted foods or allergens entirely.
            - Use only real foods and recipes that match preferred cuisines.

            === JSON OUTPUT FORMAT ===
            {{
              "day_1": {{
                "breakfast": {{"name": "", "calories": 0, "protein": 0, "carbs": 0, "fats": 0}},
                "lunch":     {{"name": "", "calories": 0, "protein": 0, "carbs": 0, "fats": 0}},
                "dinner":    {{"name": "", "calories": 0, "protein": 0, "carbs": 0, "fats": 0}}
              }},
              "day_2": {{ ... }},
              "day_3": {{ ... }},
              "day_4": {{ ... }},
              "day_5": {{ ... }},
              "day_6": {{ ... }},
              "day_7": {{ ... }}
            }}
        """

    def generate_meal_plan(self, user_profile: dict, days: int,
                           target_calories: float, macros: dict) -> dict:

        # meal_plan = {}
        #
        # for day in range(1, days + 1):
        #     prompt = self.build_prompt(user_profile, 1, target_calories, macros)
        #     result = self.call_gemini(prompt)
        #     meal_plan[f"day_{day}"] = result["day_1"]
        #
        # return meal_plan
        prompt = self.build_prompt(user_profile, days, target_calories, macros)
        return self.call_gemini(prompt)


class MealPlanService:
    def __init__(self, db: Session, gemini: GeminiMealPlanner):
        self.db = db
        self.gemini = gemini

    def generate_for_user(
        self,
        user_id: str,
        start_date: date,
        days: int,
        user_profile: dict,
        target_calories: float,
        macros: dict,
    ) -> MealPlan:

        ai_result = self.gemini.generate_meal_plan(
            user_profile=user_profile,
            days=days,
            target_calories=target_calories,
            macros=macros,
        )

        days_by_date = map_days_to_dates(start_date, ai_result)

        plan = MealPlan(
            plan_id=uuid.uuid4().hex,
            user_id=user_id,
            start_date=start_date,
            end_date=start_date + timedelta(days=days - 1),
            days=days_by_date,
            meta={
                "calories": target_calories,
                "macros": macros,
                "model": self.gemini.model,
            },
        )

        self.db.add(plan)
        self.db.commit()
        self.db.refresh(plan)
        return plan

