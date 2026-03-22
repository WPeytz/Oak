from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql+asyncpg://oak:oak@localhost:5432/oak"

    # Public base URL of this API (used for Tink redirect)
    base_url: str = "https://api.oakapp.dk"

    # Tink Open Banking
    tink_client_id: str = ""
    tink_client_secret: str = ""
    tink_base_url: str = "https://api.tink.com"

    # Set to true to use the in-memory sandbox provider instead of the real API
    tink_sandbox: bool = True

    # Deep link scheme for redirecting back to the iOS app
    ios_callback_scheme: str = "oak"

    debug: bool = False

    model_config = {"env_file": ".env"}


settings = Settings()
