"""
Centralized app configuration, loaded from environment variables (.env).
Import `settings` anywhere you need config values — never hard-code secrets.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql://agrinexus_user:changeme@localhost:5432/agrinexus_db"

    # Auth
    jwt_secret_key: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    # Weather
    weather_api_key: str = ""
    weather_api_base_url: str = "https://api.openweathermap.org/data/2.5"

    # AI model backends
    disease_model_backend: str = "mock"  # mock | tflite | torchserve
    pest_model_backend: str = "mock"
    disease_model_path: str = "./models/disease_model.tflite"
    pest_model_path: str = "./models/pest_model.tflite"

    # App
    environment: str = "development"
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    upload_dir: str = "./uploads"

    # Marketplace listing images (local dev by default; "s3" needs boto3 + S3_* vars)
    image_storage_backend: str = "local"  # local | s3
    local_upload_dir: str = "./uploads/listings"
    local_upload_url_prefix: str = "/uploads/listings"  # served by the /uploads mount
    s3_bucket_name: str = ""
    s3_region: str = ""
    s3_access_key_id: str = ""
    s3_secret_access_key: str = ""
    s3_public_url_base: str = ""

    # Community post images (Module 3). Local backend only; with
    # IMAGE_STORAGE_BACKEND=s3 the shared S3 storage is used instead.
    community_upload_dir: str = "./uploads/community"
    community_upload_url_prefix: str = "/uploads/community"

    # Chat (Module 3): the app polls for new messages; this is the interval
    # it is told to use (seconds), and the max messages per page.
    chat_poll_interval_seconds: int = 5
    chat_page_size_max: int = 100

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()


def get_settings() -> Settings:
    return settings
