from typing import Dict, Any, List
import joblib
import pandas as pd
from collections import defaultdict
import random

MODEL_PATH = "../ai/final_model_combined.pkl"
FOOD_DATASET_PATH = "../ai/food_dataset.csv"


class AIMealPlanService:
    """
    ML-based personalized meal plan generator
    """

    def __init__(self):
        self.model = joblib.load(MODEL_PATH)
        self.food_db = pd.read_csv(FOOD_DATASET_PATH).to_dict(orient="records")

    # --------------------------------------------------
    # Predict food tags (used internally)
    # --------------------------------------------------
    def _predict_tags(self, food: Dict[str, Any]) -> List[str]:
        features = pd.DataFrame([{
            "Carbs (g)": food["Carbs (g)"],
            "Protein (g)": food["Protein (g)"],
            "Fat (g)": food["Fat (g)"],
            "Calories": food["Calories"]
        }])

        preds = self.model.predict(features)[0]
        tag_names = self.model.classes_

        return [tag for tag, val in zip(tag_names, preds) if val == 1]

    # --------------------------------------------------
    # Generate weekly plan
    # --------------------------------------------------
    def generate_weekly_plan(
        self,
        user_tags: List[str],
        meals_per_day: int,
        daily_targets: Dict[str, float]
    ) -> Dict[str, Any]:

        weekdays = ["Monday", "Tuesday", "Wednesday",
                    "Thursday", "Friday", "Saturday", "Sunday"]

        meal_slots = ["Breakfast", "Lunch", "Dinner"][:meals_per_day]
        weekly_plan = {}
        grocery = defaultdict(int)

        for day in weekdays:
            day_meals = []
            totals = {
                "Calories": 0,
                "Carbs (g)": 0,
                "Protein (g)": 0,
                "Fat (g)": 0
            }

            for slot in meal_slots:
                candidates = [
                    f for f in self.food_db
                    if slot in f["meal_type"]
                    and all(tag in f["tags"] for tag in user_tags)
                ]

                random.shuffle(candidates)

                for meal in candidates:
                    if totals["Calories"] + meal["Calories"] > daily_targets["Calories"] + 150:
                        continue

                    meal_copy = dict(meal)
                    meal_copy["predicted_tags"] = self._predict_tags(meal)
                    meal_copy["meal_type"] = slot

                    day_meals.append(meal_copy)

                    for k in totals:
                        totals[k] += meal[k]

                    for ing in meal.get("ingredients", []):
                        grocery[ing] += 1

                    break

            weekly_plan[day] = {
                "meals": day_meals,
                "totals": totals
            }

        return {
            "weekly_plan": weekly_plan,
            "grocery_list": dict(grocery)
        }

