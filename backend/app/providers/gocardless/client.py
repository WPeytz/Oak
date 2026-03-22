"""Live GoCardless Bank Account Data API client.

Implements BankingProviderBase by making real HTTP calls to the
GoCardless API. Never used when GOCARDLESS_SANDBOX=true.
"""

from datetime import date, datetime, timezone

import httpx

from app.config import settings
from app.providers.gocardless.base import (
    BankingProviderBase,
    Institution,
    ProviderAccount,
    ProviderTransaction,
    Requisition,
    TokenPair,
)


class GoCardlessClient(BankingProviderBase):
    """Production client for the GoCardless Bank Account Data API v2."""

    def __init__(self) -> None:
        self._base_url = settings.gocardless_base_url
        self._secret_id = settings.gocardless_secret_id
        self._secret_key = settings.gocardless_secret_key
        self._http = httpx.AsyncClient(
            base_url=self._base_url,
            timeout=30.0,
        )
        self._token: TokenPair | None = None

    async def _ensure_token(self) -> str:
        if self._token is None or self._token.access_expires_at <= datetime.now(
            timezone.utc
        ):
            self._token = await self.obtain_token()
        return self._token.access

    async def _auth_headers(self) -> dict[str, str]:
        token = await self._ensure_token()
        return {"Authorization": f"Bearer {token}"}

    # -- Auth ---------------------------------------------------------------

    async def obtain_token(self) -> TokenPair:
        resp = await self._http.post(
            "/token/new/",
            json={
                "secret_id": self._secret_id,
                "secret_key": self._secret_key,
            },
        )
        resp.raise_for_status()
        data = resp.json()
        now = datetime.now(timezone.utc)
        return TokenPair(
            access=data["access"],
            refresh=data["refresh"],
            access_expires_at=now + _seconds(data["access_expires"]),
            refresh_expires_at=now + _seconds(data["refresh_expires"]),
        )

    async def refresh_token(self, refresh: str) -> TokenPair:
        resp = await self._http.post(
            "/token/refresh/",
            json={"refresh": refresh},
        )
        resp.raise_for_status()
        data = resp.json()
        now = datetime.now(timezone.utc)
        return TokenPair(
            access=data["access"],
            refresh=refresh,
            access_expires_at=now + _seconds(data["access_expires"]),
            refresh_expires_at=now + _seconds(data.get("refresh_expires", 86400 * 30)),
        )

    # -- Institutions -------------------------------------------------------

    async def list_institutions(self, country: str) -> list[Institution]:
        headers = await self._auth_headers()
        resp = await self._http.get(
            "/institutions/",
            params={"country": country.lower()},
            headers=headers,
        )
        resp.raise_for_status()
        return [_parse_institution(i) for i in resp.json()]

    async def get_institution(self, institution_id: str) -> Institution:
        headers = await self._auth_headers()
        resp = await self._http.get(
            f"/institutions/{institution_id}/",
            headers=headers,
        )
        resp.raise_for_status()
        return _parse_institution(resp.json())

    # -- Requisitions -------------------------------------------------------

    async def create_requisition(
        self,
        redirect_url: str,
        institution_id: str,
        reference: str | None = None,
    ) -> Requisition:
        headers = await self._auth_headers()
        body: dict = {
            "redirect": redirect_url,
            "institution_id": institution_id,
        }
        if reference:
            body["reference"] = reference
        resp = await self._http.post(
            "/requisitions/",
            json=body,
            headers=headers,
        )
        resp.raise_for_status()
        return _parse_requisition(resp.json())

    async def get_requisition(self, requisition_id: str) -> Requisition:
        headers = await self._auth_headers()
        resp = await self._http.get(
            f"/requisitions/{requisition_id}/",
            headers=headers,
        )
        resp.raise_for_status()
        return _parse_requisition(resp.json())

    # -- Accounts -----------------------------------------------------------

    async def get_account_details(self, account_id: str) -> ProviderAccount:
        headers = await self._auth_headers()
        resp = await self._http.get(
            f"/accounts/{account_id}/details/",
            headers=headers,
        )
        resp.raise_for_status()
        acct = resp.json().get("account", resp.json())
        return ProviderAccount(
            id=account_id,
            iban=acct.get("iban"),
            name=acct.get("name", acct.get("product", "Unknown")),
            currency=acct.get("currency", "EUR"),
        )

    # -- Transactions -------------------------------------------------------

    async def list_transactions(
        self,
        account_id: str,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> list[ProviderTransaction]:
        headers = await self._auth_headers()
        params: dict[str, str] = {}
        if date_from:
            params["date_from"] = date_from.isoformat()
        if date_to:
            params["date_to"] = date_to.isoformat()
        resp = await self._http.get(
            f"/accounts/{account_id}/transactions/",
            params=params,
            headers=headers,
        )
        resp.raise_for_status()
        booked = resp.json().get("transactions", {}).get("booked", [])
        return [_parse_transaction(t) for t in booked]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

from datetime import timedelta


def _seconds(n: int) -> timedelta:
    return timedelta(seconds=n)


def _parse_institution(data: dict) -> Institution:
    return Institution(
        id=data["id"],
        name=data["name"],
        logo_url=data.get("logo", ""),
        countries=data.get("countries", []),
    )


def _parse_requisition(data: dict) -> Requisition:
    return Requisition(
        id=data["id"],
        redirect_url=data.get("link", data.get("redirect", "")),
        institution_id=data.get("institution_id", ""),
        status=data.get("status", "CR"),
        accounts=data.get("accounts", []),
    )


def _parse_transaction(data: dict) -> ProviderTransaction:
    return ProviderTransaction(
        transaction_id=data.get("transactionId", data.get("internalTransactionId", "")),
        booked_at=date.fromisoformat(data["bookingDate"]),
        value_date=(
            date.fromisoformat(data["valueDate"]) if data.get("valueDate") else None
        ),
        amount=data["transactionAmount"]["amount"],
        currency=data["transactionAmount"]["currency"],
        merchant=data.get("creditorName") or data.get("debtorName"),
        description=data.get("remittanceInformationUnstructured"),
        category=data.get("proprietaryBankTransactionCode"),
    )
