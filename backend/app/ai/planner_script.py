
# Weekly Meal Planner with Nutrition Targets and Model Integration + Visualization
from typing import List, Dict
import random
from collections import defaultdict
import joblib
import pandas as pd
import matplotlib.pyplot as plt

MODEL_PATH = "final_model_combined.pkl"
model = joblib.load(MODEL_PATH)

food_db = pd.read_csv("food_dataset.csv").to_dict(orient="records")

def predict_tags(food_item: Dict) -> List[str]:
    features = pd.DataFrame([{k: food_item[k] for k in ["Carbs (g)", "Protein (g)", "Fat (g)", "Calories"]}])
    preds = model.predict(features)[0]
    tag_names = model.classes_ if hasattr(model, "classes_") else ["GlutenFree", "LowGI", "Vegan", "LowFat", "NonVeg"]
    return [tag for tag, val in zip(tag_names, preds) if val == 1]

def generate_weekly_meal_plan(user_tags: List[str], meals_per_day: int = 3, daily_targets: Dict = None) -> Dict:
    weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    meal_slots = ["Breakfast", "Lunch", "Dinner"][:meals_per_day]

    weekly_plan = {}
    used = set()
    grocery = defaultdict(int)

    for day in weekdays:
        day_plan = []
        totals = {"Calories": 0, "Carbs (g)": 0, "Protein (g)": 0, "Fat (g)": 0}

        for slot in meal_slots:
            candidates = [f for f in food_db if slot in f["meal_type"] and all(tag in f["tags"] for tag in user_tags)]
            candidates.sort(key=lambda x: abs(daily_targets["Calories"] / meals_per_day - x["Calories"])) if daily_targets else None

            for meal in candidates:
                if totals["Calories"] + meal["Calories"] > daily_targets["Calories"] + 150:
                    continue
                meal["predicted_tags"] = predict_tags(meal)
                meal["meal"] = slot
                day_plan.append(meal)
                for k in totals:
                    totals[k] += meal[k]
                for ing in meal["ingredients"]:
                    grocery[ing] += 1
                break

        weekly_plan[day] = {"meals": day_plan, "totals": totals}

    return {"weekly_plan": weekly_plan, "grocery_list": dict(grocery)}

def plot_weekly_nutrition(weekly_plan: Dict):
    days = list(weekly_plan.keys())
    calories = [weekly_plan[day]["totals"]["Calories"] for day in days]
    carbs = [weekly_plan[day]["totals"]["Carbs (g)"] for day in days]
    protein = [weekly_plan[day]["totals"]["Protein (g)"] for day in days]
    fat = [weekly_plan[day]["totals"]["Fat (g)"] for day in days]

    plt.figure(figsize=(10, 6))
    plt.plot(days, calories, marker='o', label="Calories")
    plt.plot(days, carbs, marker='o', label="Carbs (g)")
    plt.plot(days, protein, marker='o', label="Protein (g)")
    plt.plot(days, fat, marker='o', label="Fat (g)")
    plt.title("Weekly Nutrition Summary")
    plt.xlabel("Day")
    plt.ylabel("Amount")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()
