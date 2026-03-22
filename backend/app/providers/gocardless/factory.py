"""Factory that returns the correct BankingProvider based on config."""

from app.config import settings
from app.providers.gocardless.base import BankingProviderBase


def get_banking_provider() -> BankingProviderBase:
    """Return sandbox or live provider based on GOCARDLESS_SANDBOX setting."""
    if settings.gocardless_sandbox:
        from app.providers.gocardless.sandbox import SandboxBankingProvider

        return SandboxBankingProvider()

    from app.providers.gocardless.client import GoCardlessClient

    if not settings.gocardless_secret_id or not settings.gocardless_secret_key:
        raise RuntimeError(
            "GOCARDLESS_SECRET_ID and GOCARDLESS_SECRET_KEY must be set "
            "when GOCARDLESS_SANDBOX=false"
        )

    return GoCardlessClient()
