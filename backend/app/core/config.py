from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


    APP_ENV: str = "development"
    GOOGLE_APPLICATION_CREDENTIALS: str = "serviceAccountKey.json"
    CORS_ALLOW_ORIGINS: str = "*"

    # MySQL Configuration
    MYSQL_HOST: str = "localhost"
    MYSQL_PORT: int = 3306
    MYSQL_USER: str = "root"
    MYSQL_PASSWORD: str | None = Field(default=None, alias="MYSQL_PASSWORD")
    MYSQL_DB: str = "macromate_db"
    MYSQL_URL: str = ""

    # MongoDB Configuration
    MONGO_URI: str = "mongodb://localhost:27017/macromate_app_data"
    MONGO_DB_NAME: str = "macromate_app_data"

    # Food API Config
    FOOD_API_PROVIDERS: list[str] = ["usda"]
    USDA_API_KEY: str | None = None
    # FOOD_API_PROVIDE = "usda"
    # USDA_API_KEY = None

settings = Settings()
