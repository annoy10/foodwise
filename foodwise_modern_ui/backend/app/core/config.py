from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://foodwise:foodwise_dev_password@localhost:5432/foodwise"
    secret_key: str = "dev-only-change-this-secret-before-deployment"
    access_token_expire_minutes: int = 60
    ollama_base_url: str = "http://localhost:11434"
    ollama_chat_model: str = "qwen2.5:3b"
    ollama_embed_model: str = "nomic-embed-text"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
