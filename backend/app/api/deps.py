from fastapi import Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.services.food_service import FoodAPIClient
from app.services.food_log_service import FoodLogService
from app.services.nutrition_service import NutritionService
from app.services.onboarding_service import OnboardingService
from app.services.user_service import UserService
from app.services.weight_service import WeightService
from app.auth.deps import Principal, get_current_user
from app.services.workout_service import WorkoutService

def get_user_service(db: Session = Depends(get_db)) -> UserService:
    """Dependency to get the UserService instance."""
    return UserService(db)

def get_onboarding_service(db: Session = Depends(get_db)) -> OnboardingService:
    """Dependency to get the OnboardingService instance."""
    return OnboardingService(db)

def get_nutrition_service(db: Session = Depends(get_db)) -> NutritionService:
    """Dependency to get the NutritionService instance."""
    return NutritionService(db)

def get_food_service() -> FoodAPIClient:
    """Dependency to get the NutritionService instance."""
    return FoodAPIClient()

def get_food_log_service(db: Session = Depends(get_db)) -> FoodLogService:
    """Dependency to get the NutritionService instance."""
    return FoodLogService(db)

def get_weight_service(db: Session = Depends(get_db)) -> WeightService:
    return WeightService(db)

def get_workout_service(db: Session = Depends(get_db)) -> WorkoutService:
    return WorkoutService(db)

# __all__ = ["get_weight_service", "Principal", "get_current_user", "get_user_service", "get_onboarding_service", "get_db"]
__all__ = [
    "get_user_service",
    "get_onboarding_service",
    "get_nutrition_service",
    "get_food_log_service",
    "get_weight_service",
    "get_db",
    "Principal",
    "get_current_user",
]
