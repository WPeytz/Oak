"""In-memory sandbox implementation of BankingProviderBase.

Returns deterministic fake data so the app can be developed and tested
without real Tink credentials or network access.
"""

import uuid
from datetime import date, datetime, timedelta, timezone

from app.providers.tink.base import (
    BankingProviderBase,
    Institution,
    ProviderAccount,
    ProviderTransaction,
    Requisition,
    TokenPair,
)

# ---------------------------------------------------------------------------
# Canned data
# ---------------------------------------------------------------------------

SANDBOX_INSTITUTIONS = [
    Institution(
        id="dk-danskebank-business",
        name="Danske Bank",
        logo_url="https://cdn.tink.se/provider-images/dk-danskebank.png",
        countries=["DK"],
    ),
    Institution(
        id="dk-nordea-open-banking",
        name="Nordea",
        logo_url="https://cdn.tink.se/provider-images/dk-nordea.png",
        countries=["DK"],
    ),
    Institution(
        id="dk-jyskebank-open-banking",
        name="Jyske Bank",
        logo_url="https://cdn.tink.se/provider-images/dk-jyskebank.png",
        countries=["DK"],
    ),
]

SANDBOX_ACCOUNT = ProviderAccount(
    id="sandbox-account-001",
    iban="DK50 0040 0440 1162 43",
    name="Lønkonto",
    currency="DKK",
)

_TODAY = date.today()


def _sandbox_transactions() -> list[ProviderTransaction]:
    """Generate a month of realistic-looking sandbox transactions."""
    entries = [
        (-249.00, "Netto", "Groceries", -1),
        (-89.00, "Starbucks", "Eating Out", -2),
        (-1299.00, "Zalando", "Shopping", -3),
        (12500.00, "SU Stipendium", "Income", -4),
        (-450.00, "Fitness World", "Subscriptions", -5),
        (-199.00, "Netflix", "Subscriptions", -6),
        (-320.00, "Føtex", "Groceries", -7),
        (-785.00, "Restaurant Amalfi", "Eating Out", -10),
        (-150.00, "7-Eleven", "Groceries", -12),
        (-2100.00, "H&M", "Shopping", -14),
        (-59.00, "Spotify", "Subscriptions", -15),
        (-175.00, "Irma", "Groceries", -18),
        (-3200.00, "Apple Store", "Shopping", -20),
        (-410.00, "Joe & The Juice", "Eating Out", -22),
        (-290.00, "Rema 1000", "Groceries", -25),
    ]
    txns = []
    for amount, merchant, category, day_offset in entries:
        txn_date = _TODAY + timedelta(days=day_offset)
        txns.append(
            ProviderTransaction(
                transaction_id=f"sandbox-txn-{uuid.uuid4().hex[:8]}",
                booked_at=txn_date,
                value_date=txn_date,
                amount=str(amount),
                currency="DKK",
                merchant=merchant,
                description=f"Payment to {merchant}",
                category=category,
            )
        )
    return txns


# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------


class SandboxBankingProvider(BankingProviderBase):
    """Fully in-memory provider for development and testing."""

    def __init__(self) -> None:
        self._requisitions: dict[str, Requisition] = {}

    # -- Auth ---------------------------------------------------------------

    async def obtain_token(self) -> TokenPair:
        now = datetime.now(timezone.utc)
        return TokenPair(
            access="sandbox-access-token",
            refresh="sandbox-refresh-token",
            access_expires_at=now + timedelta(days=1),
            refresh_expires_at=now + timedelta(days=30),
        )

    async def refresh_token(self, refresh: str) -> TokenPair:
        return await self.obtain_token()

    # -- Institutions -------------------------------------------------------

    async def list_institutions(self, country: str) -> list[Institution]:
        return [
            inst
            for inst in SANDBOX_INSTITUTIONS
            if country.upper() in inst.countries
        ]

    async def get_institution(self, institution_id: str) -> Institution:
        for inst in SANDBOX_INSTITUTIONS:
            if inst.id == institution_id:
                return inst
        raise ValueError(f"Unknown sandbox institution: {institution_id}")

    # -- Requisitions -------------------------------------------------------

    async def create_requisition(
        self,
        redirect_url: str,
        institution_id: str,
        reference: str | None = None,
    ) -> Requisition:
        req_id = f"sandbox-req-{uuid.uuid4().hex[:8]}"
        req = Requisition(
            id=req_id,
            redirect_url=redirect_url,
            institution_id=institution_id,
            status="linked",  # immediately linked in sandbox
            accounts=[SANDBOX_ACCOUNT.id],
        )
        self._requisitions[req_id] = req
        return req

    async def get_requisition(self, requisition_id: str) -> Requisition:
        if requisition_id in self._requisitions:
            return self._requisitions[requisition_id]
        return Requisition(
            id=requisition_id,
            redirect_url="",
            institution_id=SANDBOX_INSTITUTIONS[0].id,
            status="linked",
            accounts=[SANDBOX_ACCOUNT.id],
        )

    # -- Accounts -----------------------------------------------------------

    async def get_account_details(self, account_id: str) -> ProviderAccount:
        return SANDBOX_ACCOUNT

    # -- Transactions -------------------------------------------------------

    async def list_transactions(
        self,
        account_id: str,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> list[ProviderTransaction]:
        txns = _sandbox_transactions()
        if date_from:
            txns = [t for t in txns if t.booked_at >= date_from]
        if date_to:
            txns = [t for t in txns if t.booked_at <= date_to]
        return txns
