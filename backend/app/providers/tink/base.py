"""Abstract interface for the banking data provider.

All provider implementations (Tink live API, sandbox) conform to this
contract so the rest of the app never touches HTTP or provider-specific details.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import date, datetime


# ---------------------------------------------------------------------------
# Data transfer objects — provider-agnostic representations
# ---------------------------------------------------------------------------


@dataclass
class TokenPair:
    access: str
    refresh: str
    access_expires_at: datetime
    refresh_expires_at: datetime


@dataclass
class Institution:
    id: str
    name: str
    logo_url: str
    countries: list[str] = field(default_factory=list)


@dataclass
class Requisition:
    """A user authorization session.

    In Tink terms this maps to a Tink Link session / credentials object.
    The field names stay provider-agnostic for the rest of the app.
    """

    id: str
    redirect_url: str  # The Tink Link URL the user must visit
    institution_id: str
    status: str  # pending | linked | expired | revoked
    accounts: list[str] = field(default_factory=list)


@dataclass
class ProviderAccount:
    id: str
    iban: str | None
    name: str
    currency: str


@dataclass
class ProviderTransaction:
    transaction_id: str
    booked_at: date
    value_date: date | None
    amount: str  # string to preserve precision from API
    currency: str
    merchant: str | None
    description: str | None
    category: str | None


# ---------------------------------------------------------------------------
# Abstract base
# ---------------------------------------------------------------------------


class BankingProviderBase(ABC):
    """Contract that every banking data provider must satisfy."""

    # -- Auth ---------------------------------------------------------------

    @abstractmethod
    async def obtain_token(self) -> TokenPair:
        """Exchange client credentials for an access token."""
        ...

    @abstractmethod
    async def refresh_token(self, refresh: str) -> TokenPair:
        """Refresh an expired access token."""
        ...

    # -- Institutions -------------------------------------------------------

    @abstractmethod
    async def list_institutions(self, country: str) -> list[Institution]:
        """Return institutions available in *country* (ISO 3166-1 alpha-2)."""
        ...

    @abstractmethod
    async def get_institution(self, institution_id: str) -> Institution:
        """Return a single institution by its provider ID."""
        ...

    # -- Authorization sessions ---------------------------------------------

    @abstractmethod
    async def create_requisition(
        self,
        redirect_url: str,
        institution_id: str,
        reference: str | None = None,
    ) -> Requisition:
        """Start an end-user authorization session (Tink Link).

        Returns a Requisition with a ``redirect_url`` the user must visit to
        authorize access at their bank.
        """
        ...

    @abstractmethod
    async def get_requisition(self, requisition_id: str) -> Requisition:
        """Fetch current status and linked account IDs for a session."""
        ...

    # -- Accounts -----------------------------------------------------------

    @abstractmethod
    async def get_account_details(
        self, account_id: str
    ) -> ProviderAccount:
        """Fetch metadata for a linked bank account."""
        ...

    # -- Transactions -------------------------------------------------------

    @abstractmethod
    async def list_transactions(
        self,
        account_id: str,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> list[ProviderTransaction]:
        """Fetch booked transactions for an account within a date range."""
        ...
