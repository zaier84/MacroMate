from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI
from .config import settings

def setup_cors(app: FastAPI):
    origins = settings.cors_origins_list()
    # If origins contains "*", allow all
    if origins == ["*"]:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    else:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
