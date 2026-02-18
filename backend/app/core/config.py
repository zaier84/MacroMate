from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import SecretStr
from urllib.parse import quote_plus

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # General
    APP_ENV: str = "development"
    DEBUG: bool = False

    # Firebase / Service account (either path or JSON string)
    GOOGLE_APPLICATION_CREDENTIALS: str | None = None
    FIREBASE_SERVICE_ACCOUNT_JSON: str | None = None

    # CORS - comma-separated list OR JSON array in env
    CORS_ALLOW_ORIGINS: str = "*"  # e.g. "http://localhost:3000,http://127.0.0.1:3000"

    # MySQL
    MYSQL_HOST: str = "localhost"
    MYSQL_PORT: int = 3306
    MYSQL_USER: str = "root"
    MYSQL_PASSWORD: SecretStr | None = None
    MYSQL_DB: str = "macromate_db"
    MYSQL_URL: str = ""
    # allow full URL override
    DATABASE_URL: str | None = None

    GEMINI_API_KEY: str

    # Mongo
    MONGO_URI: str = "mongodb://localhost:27017/macromate_app_data"
    MONGO_DB_NAME: str = "macromate_app_data"

    # Food API provider
    FOOD_API_PROVIDER: str = "usda"
    USDA_API_KEY: SecretStr | None = None
    # USDA_API_KEY: SecretStr | None = None

    def mysql_url(self) -> str:
        """
        Return SQLAlchemy URL. If DATABASE_URL is set, return it,
        otherwise build from MYSQL_* parts.
        """
        if self.DATABASE_URL:
            return self.DATABASE_URL
        pwd = (
            quote_plus(self.MYSQL_PASSWORD.get_secret_value())
            if self.MYSQL_PASSWORD
            else ""
        )
        # mysql+mysqlconnector://user:pwd@host:port/db
        if pwd:
            return f"mysql+mysqlconnector://{self.MYSQL_USER}:{pwd}@{self.MYSQL_HOST}:{self.MYSQL_PORT}/{self.MYSQL_DB}"
        return f"mysql+mysqlconnector://{self.MYSQL_USER}@{self.MYSQL_HOST}:{self.MYSQL_PORT}/{self.MYSQL_DB}"

    def cors_origins_list(self) -> list[str]:
        raw = (self.CORS_ALLOW_ORIGINS or "").strip()
        if raw in ("", "*"):
            return ["*"]
        # allow comma separated OR JSON array-like
        if raw.startswith("[") and raw.endswith("]"):
            try:
                import json
                arr = json.loads(raw)
                if isinstance(arr, list):
                    return [str(x) for x in arr]
            except Exception:
                pass
        return [x.strip() for x in raw.split(",") if x.strip()]

settings = Settings()

