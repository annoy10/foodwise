
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # PostgreSQL / Supabase
    database_url: str

    # JWT Authentication
    secret_key: str
    access_token_expire_minutes: int = 60

    # Ollama AI Models
    ollama_base_url: str = "http://localhost:11434"
    ollama_chat_model: str = "qwen2.5:3b"
    ollama_embed_model: str = "nomic-embed-text"

    # Load environment variables from .env
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
