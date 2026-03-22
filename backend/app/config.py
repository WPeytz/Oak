from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql+asyncpg://oak:oak@localhost:5432/oak"

    # Public base URL of this API (used for GoCardless redirect)
    base_url: str = "https://api.oakapp.dk"

    # GoCardless Bank Account Data
    gocardless_secret_id: str = ""
    gocardless_secret_key: str = ""
    gocardless_base_url: str = "https://bankaccountdata.gocardless.com/api/v2"

    # Set to true to use the in-memory sandbox provider instead of the real API
    gocardless_sandbox: bool = True

    # Deep link scheme for redirecting back to the iOS app
    ios_callback_scheme: str = "oak"

    debug: bool = False

    model_config = {"env_file": ".env"}


settings = Settings()
