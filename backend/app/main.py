from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.core.cors import setup_cors
from app.auth.firebase import init_firebase
from app.core.database import connect_to_mongo, close_mongo_connection
import logging

from app.api.routes import(
    auth_router,
    onboarding_router,
    protected_router,
    users_router,
    nutrition_router,
    foods_router,
    weights_router,
    workouts_router,
)

logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(fastapi: FastAPI):
    """
    Handles startup and shutdown events for the application.
    """
    logger.info("Application startup...")
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

    return app

app = create_app()
