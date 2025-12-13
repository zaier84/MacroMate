from datetime import datetime
from fastapi import Depends
from pymongo.database import Database
from app.core.database import get_mongo_db
from app.models.mongo_models import UserProjection
from app.services.user_service import event_queue # Import the in-memory queue
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

class ProjectionService:
    def __init__(self, mongo_db: Database):
        self.users_projection_collection = mongo_db.get_collection("users_projection")

    def process_events(self):
        """
        Processes events from the in-memory queue and updates MongoDB projections.
        In a real system, this would be triggered by a message broker listener.
        """
        while event_queue:
            event = event_queue.pop(0) # Get the oldest event
            event_type = event["type"]
            payload = event["payload"]
            
            if event_type == "UserCreated":
                print("\n\n\nRUNNING!!!!\n\n\n")
                self._handle_user_created(payload)
            elif event_type == "UserUpdated":
                self._handle_user_updated(payload)
            elif event_type == "UserOnboardingStepSaved":
                self._handle_onboarding_step_saved(payload)
            elif event_type == "OnboardingCompleted":
                self._handle_onboarding_completed(payload)
            # Add handlers for other event types as needed
            else:
                logger.warning(f"Unknown event type: {event_type}")

    def _handle_user_created(self, payload: Dict[str, Any]):
        """Handles UserCreated event to create user projection."""
        try:
            # Extract relevant fields for projection
            user_projection_data = {
                "_id": payload["user_id"],
                "email": payload["email"],
                "name": payload.get("name"),
                "goal": payload.get("goal"),
                "diet_type": payload.get("preferences", {}).get("diet_type"), # Extract specific preference
                "allergies": payload.get("allergies"),
                "status": payload.get("status", "active"),
                "last_synced": payload["timestamp"] # Use event timestamp for initial sync
            }
            user_projection = UserProjection(**user_projection_data)
            
            self.users_projection_collection.insert_one(user_projection.model_dump(by_alias=True))
            logger.info(f"User projection created for {payload['user_id']}")
        except Exception as e:
            logger.error(f"Error creating user projection for {payload['user_id']}: {e}")

    def _handle_user_updated(self, payload: Dict[str, Any]):
        """Handles UserUpdated event to update user projection."""
        user_id = payload["user_id"]
        updated_fields = payload["updated_fields"]
        
        # Prepare update document for MongoDB
        mongo_update_doc = {"$set": {}}
        
        for key, value in updated_fields.items():
            if key == "preferences":
                # If preferences changed, update diet_type in projection
                if "diet_type" in value:
                    mongo_update_doc["$set"]["diet_type"] = value["diet_type"]
                # You might need more sophisticated logic here if preferences are complex
            elif key == "allergies":
                mongo_update_doc["$set"]["allergies"] = value
            elif key == "goal":
                mongo_update_doc["$set"]["goal"] = value
            elif key == "name":
                mongo_update_doc["$set"]["name"] = value
            elif key == "email":
                mongo_update_doc["$set"]["email"] = value
            # Add other fields that should be projected
        
        mongo_update_doc["$set"]["last_synced"] = datetime.utcnow() # Update sync timestamp

        if mongo_update_doc["$set"]: # Only update if there are fields to set
            try:
                self.users_projection_collection.update_one(
                    {"_id": user_id},
                    mongo_update_doc,
                    upsert=False # Do not create if not exists, it should exist from UserCreated
                )
                logger.info(f"User projection updated for {user_id} with fields: {list(mongo_update_doc['$set'].keys())}")
            except Exception as e:
                logger.error(f"Error updating user projection for {user_id}: {e}")
    def _handle_onboarding_step_saved(self, payload: Dict[str, Any]):
        """
        Update the users_projection onboarding subdocument for fast reads.
        payload: { user_id, step, payload, timestamp }
        """
        try:
            user_id = payload["user_id"]
            step = payload.get("step")
            step_payload = payload.get("payload")
            ts = payload.get("timestamp")

            update_doc = {
                "$set": {
                    f"onboarding.progress.{step}": step_payload,
                    "onboarding.current_step": step,
                    "onboarding.last_saved": ts
                }
            }
            # upsert projection if not exists
            self.users_projection_collection.update_one(
                {"_id": user_id},
                update_doc,
                upsert=True
            )
            logger.info(f"Updated onboarding step '{step}' for user {user_id} in projection")
        except Exception as e:
            logger.error(f"Error updating onboarding projection: {e}")

    def _handle_onboarding_completed(self, payload: Dict[str, Any]):
        """
        Mark onboarding complete in projection, store a short summary and timestamp.
        """
        try:
            user_id = payload["user_id"]
            summary = payload.get("summary", {})
            ts = payload.get("timestamp")
            # Set is_complete flag and save summary
            update_doc = {
                "$set": {
                    "onboarding.is_complete": True,
                    "onboarding.completed_at": ts,
                    "onboarding.summary": summary
                }
            }
            self.users_projection_collection.update_one(
                {"_id": user_id},
                update_doc,
                upsert=True
            )
            logger.info(f"Onboarding completed projection updated for user {user_id}")
        except Exception as e:
            logger.error(f"Error in onboarding completed projection handler: {e}")

# --- Dependency for Projection Service ---
def get_projection_service(mongo_db: Database = Depends(get_mongo_db)) -> ProjectionService:
    """Dependency to get the ProjectionService instance."""
    return ProjectionService(mongo_db)


