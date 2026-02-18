import json
import time
from typing import Any

from google import genai


class GeminiMealPlanner:
    """
    Gemini-powered AI meal plan generator.

    Responsibilities:
    - Prompt construction
    - Safe Gemini API calls
    - Strict JSON extraction
    """

    def __init__(
        self,
        api_key: str,
        model: str = "gemini-2.5-flash",
        retry_delay: float = 1.0,
    ):
        self.client = genai.Client(api_key=api_key)
        self.model = model
        self.retry_delay = retry_delay

    # ---------------------------------------------------------
    # Public API
    # ---------------------------------------------------------

    def generate_meal_plan(
        self,
        user_profile: dict[str, Any],
        days: int,
        target_calories: float,
        macros: dict[str, float],
        max_retries: int = 3,
    ) -> dict[str, Any]:
        """
        Generate a multi-day meal plan.

        Returns:
            {
              "day_1": {...},
              "day_2": {...},
              ...
            }
        """
        prompt = self._build_prompt(
            user_profile=user_profile,
            days=days,
            target_calories=target_calories,
            macros=macros,
        )

        return self._call_gemini(prompt, max_retries)

    # ---------------------------------------------------------
    # Gemini call (NULL SAFE)
    # ---------------------------------------------------------

    def _call_gemini(
        self,
        prompt: str,
        max_retries: int,
    ) -> dict[str, Any]:
        last_error: Exception | None = None

        for attempt in range(1, max_retries + 1):
            try:
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=prompt,
                )

                # -------- SAFETY CHECKS --------
                if (
                    response is None
                    or not getattr(response, "candidates", None)
                    or not response.candidates
                ):
                    raise ValueError("Gemini returned empty candidates")

                candidate = response.candidates[0]
                content = getattr(candidate, "content", None)

                if content is None:
                    raise ValueError("Gemini returned empty content")

                text = str(content).strip()
                json_text = self._extract_json(text)

                return json.loads(json_text)

            except Exception as e:
                last_error = e
                if attempt < max_retries:
                    time.sleep(self.retry_delay)
                else:
                    break

        raise RuntimeError(
            f"Gemini request failed after {max_retries} attempts: {last_error}"
        )

    # ---------------------------------------------------------
    # Prompt
    # ---------------------------------------------------------

    def _build_prompt(
        self,
        user_profile: dict[str, Any],
        days: int,
        target_calories: float,
        macros: dict[str, float],
    ) -> str:
        restrictions = ", ".join(
            user_profile.get("dietary_restrictions", [])
        ) or "none"

        allergies = ", ".join(
            user_profile.get("allergies", [])
        ) or "none"

        cuisines = ", ".join(
            user_profile.get("cuisine_preferences", [])
        ) or "any"

        meals_per_day = ", ".join(
            user_profile.get("meals_per_day", [])
        ) or "breakfast, lunch, dinner"

        print(macros)

        return f"""
            You are a professional nutritionist AI.

            Generate a STRICTLY VALID JSON meal plan for {days} day(s) ONLY.

            === USER PROFILE ===
            Goal: {user_profile.get("goal", "maintain")}
            Meals per day: {meals_per_day}
            Calories per day: {int(target_calories)}

            Daily Macros:
            - Protein: {int(macros["protein_g"])}g
            - Carbs: {int(macros["carbs_g"])}g
            - Fats: {int(macros["fats_g"])}g

            Dietary Restrictions: {restrictions}
            Allergies: {allergies}
            Cuisine Preferences: {cuisines}

            === RULES ===
            - RETURN ONLY JSON. NO TEXT.
            - NO comments, NO trailing commas.
            - Each meal must include:
              name, calories, protein, carbs, fats
            - Daily calories must be within ±5%
            - Daily macros must be within ±5%
            - Distribution:
              Breakfast ~25%
              Lunch ~35%
              Dinner ~40%
            - Use real foods only.
            - Avoid allergens completely.

            === OUTPUT FORMAT ===
            {{
              "day_1": {{
                "breakfast": {{
                  "name": "",
                  "calories": 0,
                  "protein": 0,
                  "carbs": 0,
                  "fats": 0
                }},
                "lunch": {{
                  "name": "",
                  "calories": 0,
                  "protein": 0,
                  "carbs": 0,
                  "fats": 0
                }},
                "dinner": {{
                  "name": "",
                  "calories": 0,
                  "protein": 0,
                  "carbs": 0,
                  "fats": 0
                }}
              }}
            }}
            """

    # ---------------------------------------------------------
    # JSON extraction
    # ---------------------------------------------------------

    def _extract_json(self, text: str) -> str:
        """
        Extracts JSON safely even if Gemini adds text around it.
        """
        first_brace = text.find("{")
        last_brace = text.rfind("}")

        if first_brace == -1 or last_brace == -1:
            raise ValueError("No JSON object found in Gemini response")

        return text[first_brace:last_brace + 1]
