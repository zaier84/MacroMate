from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from pymongo import MongoClient
from pymongo.database import Database as MongoDatabase
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# --- MySQL (SQLAlchemy) Setup ---
SQLALCHEMY_DATABASE_URL = settings.mysql_url()

# Create the SQLAlchemy engine
engine = create_engine(SQLALCHEMY_DATABASE_URL, pool_pre_ping=True)

# Create a SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for declarative models
Base = declarative_base()

def get_db():
    """Dependency to get a SQLAlchemy session."""
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()

# --- MongoDB (PyMongo) Setup ---
mongo_client: MongoClient | None = None
mongo_db: MongoDatabase | None = None

def connect_to_mongo():
    """Connects to MongoDB."""
    global mongo_client, mongo_db
    try:
        mongo_client = MongoClient(settings.MONGO_URI)
        mongo_db = mongo_client.get_database(settings.MONGO_DB_NAME)
        logger.info("Connected to MongoDB successfully!")
    except Exception as e:
        logger.error(f"Could not connect to MongoDB: {e}")
        raise

def close_mongo_connection():
    """Closes the MongoDB connection."""
    global mongo_client
    if mongo_client:
        mongo_client.close()
        logger.info("MongoDB connection closed.")

def get_mongo_db() -> MongoDatabase:
    """Dependency to get the MongoDB database instance."""
    if mongo_db is None:
        raise RuntimeError("MongoDB not connected. Call connect_to_mongo() first.")
    return mongo_db

def get_mongo_client() -> MongoClient:
    """Return the global client; ensure connect_to_mongo() was called."""
    if mongo_client is None:
        raise RuntimeError("MongoDB not connected. Call connect_to_mongo() first.")
    return mongo_client
