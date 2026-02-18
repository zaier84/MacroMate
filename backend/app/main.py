from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.core.config import settings
from app.core.cors import setup_cors
from app.auth.firebase import init_firebase
from app.core.database import connect_to_mongo, close_mongo_connection
import logging
import os

from app.api.routes import(
    auth_router,
    onboarding_router,
    protected_router,
    users_router,
    nutrition_router,
    foods_router,
    weights_router,
    workouts_router,
    dashboard_router,
    recipes_router,
    # mealplans_router,
    health_router,
    progress_router,
    diary_router,
    meal_plans_router,
    snap_meal_router
)

logger = logging.getLogger(__name__)

def _validate_required_env_for_prod():
    """
    Strict validation for production. Raise RuntimeError if any required production
    config / secret is missing or looks like a default/placeholder.

    - Require either MYSQL_URL (preferred) OR all of MYSQL_HOST/MYSQL_DB/MYSQL_USER/MYSQL_PASSWORD.
    - Require MONGO_URI.
    - Require FIREBASE service account (either JSON string in env or path in GOOGLE_APPLICATION_CREDENTIALS)
    - If using USDA provider, require USDA_API_KEY
    """

    if getattr(settings, "APP_ENV", "").lower() != "production":
        return

    missing = []

    # 1) MySQL: prefer a full URL. If not present require credentials.
    mysql_url = (getattr(settings, "MYSQL_URL", "") or "").strip()
    mysql_host = (getattr(settings, "MYSQL_HOST", "") or "").strip()
    mysql_db = (getattr(settings, "MYSQL_DB", "") or "").strip()
    mysql_user = (getattr(settings, "MYSQL_USER", "") or "").strip()
    mysql_pass = (getattr(settings, "MYSQL_PASSWORD", None) or "")

    if not mysql_url:
        # require explicit credentials when URL missing
        if not (mysql_host and mysql_db and mysql_user and mysql_pass):
            missing.append("MYSQL_URL or (MYSQL_HOST, MYSQL_DB, MYSQL_USER, MYSQL_PASSWORD)")

    # 2) Mongo
    mongo_uri = (getattr(settings, "MONGO_URI", "") or "").strip()
    if not mongo_uri:
        missing.append("MONGO_URI")

    # 3) Firebase credentials
    # Accept either FIREBASE_SERVICE_ACCOUNT_JSON (stringified JSON) OR a path in GOOGLE_APPLICATION_CREDENTIALS
    fb_json = getattr(settings, "FIREBASE_SERVICE_ACCOUNT_JSON", None)
    gpath = getattr(settings, "GOOGLE_APPLICATION_CREDENTIALS", None)
    fb_ok = False
    if fb_json:
        fb_ok = True
    elif gpath:
        # if provided as path, ensure file exists (avoid false positives)
        try:
            if os.path.exists(str(gpath)):
                fb_ok = True
            else:
                # file not present -> treat as missing
                fb_ok = False
        except Exception:
            fb_ok = False

    if not fb_ok:
        missing.append("FIREBASE_SERVICE_ACCOUNT_JSON or valid GOOGLE_APPLICATION_CREDENTIALS file")

    # 4) Food API provider keys
    provs = getattr(settings, "FOOD_API_PROVIDERS", getattr(settings, "FOOD_API_PROVIDER", None))
    prov_list = provs if isinstance(provs, (list, tuple)) else [provs]
    prov_list = [p.lower() for p in (prov_list or []) if p]
    if "usda" in prov_list:
        key = getattr(settings, "USDA_API_KEY", None)
        if not key:
            missing.append("USDA_API_KEY")

    # 5) Extra optional hardening: disallow placeholder MYSQL_URL values
    if mysql_url and ("<" in mysql_url or "password" in mysql_url.lower() and ("your" in mysql_url.lower() or "changeme" in mysql_url.lower())):
        missing.append("MYSQL_URL looks like a placeholder or contains obvious placeholder text")

    if missing:
        raise RuntimeError("Missing required production environment configuration: " + ", ".join(missing))

@asynccontextmanager
async def lifespan(fastapi: FastAPI):
    """
    Handles startup and shutdown events for the application.
    """
    # logger.info("Application startup...")
    logger.info("Application startup... validating config")
    # validate required variables for prod
    _validate_required_env_for_prod()

    # initialize services
    init_firebase()
    connect_to_mongo()

    yield
    logger.info("Application Shutdown...")
    close_mongo_connection()

def create_app() -> FastAPI:
    app = FastAPI(title="MacroMate", version="1.0.0", lifespan=lifespan)
    setup_cors(app)

    app.include_router(prefix="/api", router=auth_router)
    app.include_router(prefix="/api", router=protected_router)
    app.include_router(prefix="/api", router=users_router)
    app.include_router(prefix="/api", router=onboarding_router)
    app.include_router(prefix="/api", router=nutrition_router)
    app.include_router(prefix="/api", router=foods_router)
    app.include_router(prefix="/api", router=weights_router)
    app.include_router(prefix="/api", router=workouts_router)
    app.include_router(prefix="/api", router=dashboard_router)
    app.include_router(prefix="/api", router=recipes_router)
    # app.include_router(prefix="/api", router=mealplans_router)
    app.include_router(prefix="/api", router=health_router)
    app.include_router(prefix="/api", router=progress_router)
    app.include_router(prefix="/api", router=diary_router)
    app.include_router(prefix="/api", router=meal_plans_router)
    app.include_router(prefix="/api", router=snap_meal_router)

    return app

app = create_app()
