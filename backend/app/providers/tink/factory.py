"""Factory that returns the correct BankingProvider based on config."""

from app.config import settings
from app.providers.tink.base import BankingProviderBase


def get_banking_provider() -> BankingProviderBase:
    """Return sandbox or live provider based on TINK_SANDBOX setting."""
    if settings.tink_sandbox:
        from app.providers.tink.sandbox import SandboxBankingProvider

        return SandboxBankingProvider()

    from app.providers.tink.client import TinkClient

    if not settings.tink_client_id or not settings.tink_client_secret:
        raise RuntimeError(
            "TINK_CLIENT_ID and TINK_CLIENT_SECRET must be set "
            "when TINK_SANDBOX=false"
        )

    return TinkClient()
