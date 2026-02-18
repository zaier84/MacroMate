from pprint import pprint
from planner_script import generate_weekly_meal_plan, plot_weekly_nutrition

import json
import ast
import numpy as np


def clean_output(data):
    # Recursively clean the data
    if isinstance(data, dict):
        return {k: clean_output(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [clean_output(v) for v in data]
    elif isinstance(data, np.ndarray):
        return data.tolist()
    elif isinstance(data, str):
        # Convert strings like "['eggs']" to real lists
        try:
            parsed = ast.literal_eval(data)
            return clean_output(parsed)
        except:
            return data
    else:
        return data

# Example usage
user_tags = ["NonVeg"]
daily_targets = {"Calories": 1800, "Carbs (g)": 80, "Protein (g)": 30, "Fat (g)": 20}
meals_per_day = 3

import time
start = time.time()
result = generate_weekly_meal_plan(user_tags, meals_per_day, daily_targets)
end = time.time()
cleaned = clean_output(result)

json_output = json.dumps(cleaned, indent=4)
print("Generation took", round(end-start,2), "seconds")
print(json_output)

# r = clean_output(result)
# pprint(r)
# plot_weekly_nutrition(result["weekly_plan"])
