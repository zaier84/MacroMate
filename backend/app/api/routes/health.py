from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
import logging
import os

from app.core.config import settings
from app.core.database import get_db, get_mongo_db, get_mongo_client
# from app.auth.firebase import init_firebase

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/health", tags=["health"])

@router.get("/", status_code=status.HTTP_200_OK)
def health_check():
    """Simple liveness check — process is up."""
    return {"status": "ok", "env": settings.APP_ENV}

@router.get("/ready")
def readiness_check(db = Depends(get_db)):
    """
    Readiness check — lightweight checks against key dependencies.
    - tries a simple DB ping
    - verifies Mongo connection (if configured)
    - verifies presence of firebase/service-account (either JSON or file path)
    - verifies USDA API key presence if provider == usda
    """
    problems = []

    # 1) MySQL / SQLAlchemy quick test
    try:
        # Using a light-weight SQL - also compatible across backends
        db.execute(text("SELECT 1"))
    except Exception as e:
        logger.exception("MySQL readiness check failed")
        problems.append({"mysql": str(e)})

    # 2) Mongo check (if configured)
    try:
        if settings.MONGO_URI:
            # get_mongo_db() returns a pymongo.database.Database object
            mongo_db = get_mongo_db()
            # call Database.command("ping")
            mongo_db.command("ping")
            # optionally also check admin on the client if you have get_mongo_client()
            client = get_mongo_client()
            client.admin.command("ping")
    except Exception as e:
        logger.exception("Mongo readiness check failed")
        problems.append({"mongo": str(e)})

    # 3) Firebase service account presence check (do not log contents)
    try:
        # Accept either FIREBASE_SERVICE_ACCOUNT_JSON or a valid GOOGLE_APPLICATION_CREDENTIALS path
        if settings.APP_ENV == "production":
            has_json = bool(getattr(settings, "FIREBASE_SERVICE_ACCOUNT_JSON", None))
            ga_path = getattr(settings, "GOOGLE_APPLICATION_CREDENTIALS", None)
            has_path = False
            if ga_path:
                try:
                    has_path = os.path.exists(str(ga_path))
                except Exception:
                    has_path = False

            if not (has_json or has_path):
                problems.append({"firebase": "FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS (existing file) required in production"})
    except Exception as e:
        logger.exception("Firebase readiness check failed")
        problems.append({"firebase": str(e)})

    # 4) Food API provider key (if using USDA)
    try:
        provs = getattr(settings, "FOOD_API_PROVIDERS", getattr(settings, "FOOD_API_PROVIDER", None))
        prov_list = provs if isinstance(provs, (list, tuple)) else [provs]
        if "usda" in [p.lower() for p in prov_list if p]:
            if not getattr(settings, "USDA_API_KEY", None):
                problems.append({"food_api": "USDA_API_KEY not set"})
    except Exception as e:
        logger.exception("Food API readiness check failed")
        problems.append({"food_api": str(e)})

    if problems:
        # return structured failure payload
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail={"ok": False, "problems": problems})

    return {"ok": True}
