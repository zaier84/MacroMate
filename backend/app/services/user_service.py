from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from app.models.sql_models import User
from app.schemas.user import UserCreate, UserUpdate
from fastapi import HTTPException, status
from datetime import datetime

event_queue = []

def publish_event(event_type: str, payload: dict):
    """Publishes a simple event to the in-memory queue."""
    event_queue.append({"type": event_type, "payload": payload, "timestamp": datetime.utcnow()})
    print(f"Event published: {event_type} with payload {payload}")


class UserService:
    def __init__(self, db: Session):
        self.db = db

    def create_user(self, user_id: str, user_data: UserCreate) -> User:
        """
        Creates a new user in the database.
        Publishes a UserCreated event.
        """
        db_user = User(
            user_id=user_id,
            email=user_data.email,
            name=user_data.name,
            dob=user_data.dob,
            gender=user_data.gender,
            height_cm=user_data.height_cm,
            preferences=user_data.preferences,
            goal=user_data.goal,
            allergies=user_data.allergies,
            is_profile_complete=False
        )

        try:
            self.db.add(db_user)
            self.db.commit()
            self.db.refresh(db_user)

            publish_event("UserCreated", {
                "user_id": db_user.user_id,
                "email": db_user.email,
                "name": db_user.name,
                "goal": db_user.goal,
                "preferences": db_user.preferences,
                "allergies": db_user.allergies,
                "status": "active",
                "is_profile_complete": db_user.is_profile_complete,
                "timestamp": datetime.utcnow()
            })

            return db_user
        except IntegrityError:
            self.db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this email or ID already exists."
            )
        except Exception as e:
            self.db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create user: {e}"
            )


    def get_user(self, user_id: str) -> User | None:
        """Retrieves a user by their user_id."""
        return self.db.query(User).filter(User.user_id == user_id).first()

    def update_user(self, user_id: str, user_data: UserUpdate) -> User:
        """
        Updates an existing user's profile.
        Publishes a UserUpdated event.
        """
        db_user = self.get_user(user_id)
        if not db_user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

        update_data = user_data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(db_user, key, value)

        try:
            self.db.add(db_user)
            self.db.commit()
            self.db.refresh(db_user)

            publish_event("UserUpdated", {
                "user_id": db_user.user_id,
                "updated_fields": update_data # Send only the fields that changed
            })
            return db_user
        except Exception as e:
            self.db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to update user: {e}"
            )

    def update_preferences(self, user_id: str, prefs_update: dict) -> dict | None:
        """
        Merge preferences update into user.preferences.
        - dict values are shallow-merged
        - lists/primitives replace existing values
        """
        user = self.db.query(User).filter(User.user_id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        prefs: dict = (user.preferences or {}).copy()

        try:
            for key, val in prefs_update.items():
                if val is None:
                    # skip explicit None
                    continue

                if isinstance(val, dict):
                    # shallow merge dicts
                    existing = prefs.get(key)
                    if not isinstance(existing, dict):
                        existing = {}
                    # convert keys to simple types (don't try to deep merge lists)
                    existing.update(val)
                    prefs[key] = existing
                else:
                    # primitives & lists -> replace
                    prefs[key] = val

            user.preferences = prefs
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)
            return user.preferences

        except SQLAlchemyError as e:
            self.db.rollback()
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                                detail=f"Failed to update preferences: {e}")

    def ensure_user_exists(self, user_id: str, email: str | None = None, name: str | None = None):
        """
        Create minimal user row if not exists. Returns User or None if couldn't create (missing email).
        """
        existing = self.get_user(user_id)
        if existing:
            return existing

        if not email:
            # Can't create a valid user row without email (your users.email is non-nullable)
            return None
    
        # Build a minimal UserCreate DTO and call create_user()
        user_payload = UserCreate(
            email=email,
            name=name,
        )

        return self.create_user(user_id, user_payload)

