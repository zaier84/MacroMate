import json
import time
from typing import Any, List
from google import genai
from google.genai import types


class MealSnapAnalyzer:
    """
    AI-powered meal image analyzer.

    Takes a food image and returns detected foods with
    calories and macros in a format directly compatible
    with add_food_entries().
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

    def analyze_meal_image(
        self,
        image_bytes: bytes,
        max_retries: int = 3,
    ) -> dict[str, Any]:
        prompt = self._build_prompt()

        last_error = None
        for attempt in range(1, max_retries + 1):
            try:
                response = self.client.models.generate_content(
                    model=self.model,
                    contents=[
                        prompt,
                        # {
                        #     "mime_type": "image/jpeg",
                        #     "data": image_bytes,
                        # },
                        types.Part.from_bytes(
                            data=image_bytes,
                            mime_type="image/jpeg"
                        )
                    ],
                )

                if (
                    response is None
                    or not getattr(response, "candidates", None)
                    or not response.candidates
                ):
                    raise ValueError("Gemini returned no candidates")

                content = getattr(response.candidates[0], "content", None)
                if content is None:
                    raise ValueError("Gemini returned empty content")

                text = str(content).strip()
                json_text = self._extract_json(text)
                parsed = json.loads(json_text)

                self._validate_response(parsed)
                return parsed

            except Exception as e:
                last_error = e
                if attempt < max_retries:
                    time.sleep(self.retry_delay)

        raise RuntimeError(
            f"Meal image analysis failed after {max_retries} attempts: {last_error}"
        )

    # ---------------------------------------------------------
    # Prompt
    # ---------------------------------------------------------

    def _build_prompt(self) -> str:
        return """
            You are a food recognition and nutrition estimation AI.

            Analyze the provided food image and return ONLY valid JSON.

            === TASK ===
            1. Identify each distinct food item in the image.
            2. Estimate portion size using common real-world servings.
            3. Estimate calories and macros per item.

            === IMPORTANT RULES ===
            - RETURN JSON ONLY. NO TEXT.
            - NO comments, NO trailing commas.
            - Use grams (g) or milliliters (ml) where possible.
            - Be realistic and conservative with estimates.
            - If unsure, still estimate but mark confidence as "low".

            === OUTPUT FORMAT (STRICT) ===
            {
              "foods": [
                {
                  "name": "Food name",
                  "quantity": 0,
                  "unit": "g | ml | piece",
                  "calories": 0,
                  "protein_g": 0,
                  "carbs_g": 0,
                  "fats_g": 0,
                  "food_api_id": null,
                  "raw": {
                    "confidence": "high | medium | low",
                    "estimated_from_image": true
                  }
                }
              ]
            }
            """

    # ---------------------------------------------------------
    # Validation
    # ---------------------------------------------------------

    def _validate_response(self, data: dict[str, Any]) -> None:
        if "foods" not in data or not isinstance(data["foods"], list):
            raise ValueError("Invalid response: 'foods' list missing")

        for f in data["foods"]:
            required = [
                "name",
                "quantity",
                "unit",
                "calories",
                "protein_g",
                "carbs_g",
                "fats_g",
            ]
            for key in required:
                if key not in f:
                    raise ValueError(f"Missing key in food item: {key}")

    # ---------------------------------------------------------
    # JSON extraction
    # ---------------------------------------------------------

    def _extract_json(self, text: str) -> str:
        first = text.find("{")
        last = text.rfind("}")
        if first == -1 or last == -1:
            raise ValueError("No JSON object found")
        return text[first:last + 1]

