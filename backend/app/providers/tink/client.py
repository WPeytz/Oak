"""Live Tink API client.

Implements BankingProviderBase by making real HTTP calls to the
Tink API. Never used when TINK_SANDBOX=true.

Tink API docs: https://docs.tink.com/api
"""

from datetime import date, datetime, timedelta, timezone

import httpx

from app.config import settings
from app.providers.tink.base import (
    BankingProviderBase,
    Institution,
    ProviderAccount,
    ProviderTransaction,
    Requisition,
    TokenPair,
)


class TinkClient(BankingProviderBase):
    """Production client for the Tink API."""

    def __init__(self) -> None:
        self._base_url = settings.tink_base_url
        self._client_id = settings.tink_client_id
        self._client_secret = settings.tink_client_secret
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
            "/api/v1/oauth/token",
            data={
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "grant_type": "client_credentials",
                "scope": "authorization:grant,credentials:read,accounts:read,transactions:read,providers:read",
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        resp.raise_for_status()
        data = resp.json()
        now = datetime.now(timezone.utc)
        expires_in = data.get("expires_in", 3600)
        return TokenPair(
            access=data["access_token"],
            refresh=data.get("refresh_token", ""),
            access_expires_at=now + timedelta(seconds=expires_in),
            refresh_expires_at=now + timedelta(days=30),
        )

    async def refresh_token(self, refresh: str) -> TokenPair:
        resp = await self._http.post(
            "/api/v1/oauth/token",
            data={
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "grant_type": "refresh_token",
                "refresh_token": refresh,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        resp.raise_for_status()
        data = resp.json()
        now = datetime.now(timezone.utc)
        expires_in = data.get("expires_in", 3600)
        return TokenPair(
            access=data["access_token"],
            refresh=data.get("refresh_token", refresh),
            access_expires_at=now + timedelta(seconds=expires_in),
            refresh_expires_at=now + timedelta(days=30),
        )

    # -- Institutions (Tink calls them "providers") -------------------------

    async def list_institutions(self, country: str) -> list[Institution]:
        headers = await self._auth_headers()
        resp = await self._http.get(
            "/api/v1/providers",
            params={"market": country.upper()},
            headers=headers,
        )
        resp.raise_for_status()
        providers = resp.json().get("providers", resp.json())
        if isinstance(providers, dict):
            providers = providers.get("providers", [])
        return [_parse_provider(p) for p in providers]

    async def get_institution(self, institution_id: str) -> Institution:
        headers = await self._auth_headers()
        resp = await self._http.get(
            f"/api/v1/providers/{institution_id}",
            headers=headers,
        )
        resp.raise_for_status()
        return _parse_provider(resp.json())

    # -- Authorization sessions (Tink Link) ---------------------------------

    async def create_requisition(
        self,
        redirect_url: str,
        institution_id: str,
        reference: str | None = None,
    ) -> Requisition:
        """Create a Tink Link authorization session.

        This generates a Tink Link URL that the user visits to authorize
        bank access. After completion, Tink redirects to our callback URL.
        """
        headers = await self._auth_headers()

        # Step 1: Create an authorization grant for the user
        grant_resp = await self._http.post(
            "/api/v1/oauth/authorization-grant",
            json={
                "external_user_id": reference or "oak-user",
                "scope": "accounts:read,transactions:read,credentials:read",
            },
            headers=headers,
        )
        grant_resp.raise_for_status()
        auth_code = grant_resp.json().get("code", "")

        # Step 2: Build the Tink Link URL
        tink_link_params = {
            "client_id": self._client_id,
            "redirect_uri": redirect_url,
            "market": "DK",
            "locale": "en_US",
            "authorization_code": auth_code,
        }
        if institution_id:
            tink_link_params["input_provider"] = institution_id

        from urllib.parse import urlencode

        tink_link_url = f"https://link.tink.com/1.0/transactions/connect-accounts?{urlencode(tink_link_params)}"

        # Use the auth code as our requisition ID
        return Requisition(
            id=auth_code,
            redirect_url=tink_link_url,
            institution_id=institution_id,
            status="pending",
            accounts=[],
        )

    async def get_requisition(self, requisition_id: str) -> Requisition:
        """Check credentials status for a Tink Link session.

        After the user completes Tink Link, we exchange the auth code for
        a user token and check the credentials status.
        """
        headers = await self._auth_headers()

        # Get user token from the authorization code
        token_resp = await self._http.post(
            "/api/v1/oauth/token",
            data={
                "client_id": self._client_id,
                "client_secret": self._client_secret,
                "grant_type": "authorization_code",
                "code": requisition_id,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

        if token_resp.status_code != 200:
            return Requisition(
                id=requisition_id,
                redirect_url="",
                institution_id="",
                status="pending",
                accounts=[],
            )

        user_token = token_resp.json()["access_token"]
        user_headers = {"Authorization": f"Bearer {user_token}"}

        # Check credentials
        creds_resp = await self._http.get(
            "/api/v1/credentials/list",
            headers=user_headers,
        )
        creds_resp.raise_for_status()
        credentials = creds_resp.json().get("credentials", [])

        if not credentials:
            return Requisition(
                id=requisition_id,
                redirect_url="",
                institution_id="",
                status="pending",
                accounts=[],
            )

        cred = credentials[0]
        tink_status = cred.get("status", "")
        status = _map_credential_status(tink_status)

        # Get accounts if linked
        account_ids = []
        if status == "linked":
            accounts_resp = await self._http.get(
                "/api/v1/accounts/list",
                headers=user_headers,
            )
            accounts_resp.raise_for_status()
            account_ids = [
                a["id"] for a in accounts_resp.json().get("accounts", [])
            ]

        return Requisition(
            id=requisition_id,
            redirect_url="",
            institution_id=cred.get("providerName", ""),
            status=status,
            accounts=account_ids,
        )

    # -- Accounts -----------------------------------------------------------

    async def get_account_details(self, account_id: str) -> ProviderAccount:
        headers = await self._auth_headers()
        resp = await self._http.get(
            f"/api/v1/accounts/{account_id}",
            headers=headers,
        )
        resp.raise_for_status()
        acct = resp.json()
        identifiers = acct.get("identifiers", {})
        return ProviderAccount(
            id=account_id,
            iban=identifiers.get("iban", {}).get("iban"),
            name=acct.get("name", "Unknown"),
            currency=acct.get("currencyCode", "DKK"),
        )

    # -- Transactions -------------------------------------------------------

    async def list_transactions(
        self,
        account_id: str,
        date_from: date | None = None,
        date_to: date | None = None,
    ) -> list[ProviderTransaction]:
        headers = await self._auth_headers()
        params: dict[str, str] = {"accountId": account_id}
        if date_from:
            params["startDate"] = date_from.isoformat()
        if date_to:
            params["endDate"] = date_to.isoformat()

        resp = await self._http.get(
            "/api/v1/search",
            params=params,
            headers=headers,
        )
        resp.raise_for_status()
        results = resp.json().get("results", [])
        return [_parse_transaction(t) for t in results]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _parse_provider(data: dict) -> Institution:
    return Institution(
        id=data.get("name", data.get("providerName", "")),
        name=data.get("displayName", data.get("name", "")),
        logo_url=data.get("images", {}).get("icon", ""),
        countries=data.get("markets", data.get("market", "").split(",")),
    )


def _map_credential_status(tink_status: str) -> str:
    """Map Tink credential status to our internal status."""
    mapping = {
        "UPDATED": "linked",
        "UPDATING": "pending",
        "CREATED": "pending",
        "AUTHENTICATING": "pending",
        "AWAITING_MOBILE_BANKID_AUTHENTICATION": "pending",
        "AWAITING_SUPPLEMENTAL_INFORMATION": "pending",
        "DISABLED": "revoked",
        "SESSION_EXPIRED": "expired",
        "TEMPORARY_ERROR": "pending",
        "PERMANENT_ERROR": "revoked",
        "DELETED": "revoked",
    }
    return mapping.get(tink_status, "pending")


def _parse_transaction(data: dict) -> ProviderTransaction:
    transaction = data if "id" in data else data.get("transaction", data)
    amount_value = transaction.get("amount", {})
    if isinstance(amount_value, dict):
        amount = str(amount_value.get("value", {}).get("unscaledValue", "0"))
        scale = amount_value.get("value", {}).get("scale", 0)
        if scale:
            amount = str(float(amount) / (10**scale))
        currency = amount_value.get("currencyCode", "DKK")
    else:
        amount = str(amount_value)
        currency = "DKK"

    booked_str = transaction.get("dates", {}).get("booked", transaction.get("date", ""))
    booked_at = date.fromisoformat(booked_str) if booked_str else date.today()

    return ProviderTransaction(
        transaction_id=transaction.get("id", ""),
        booked_at=booked_at,
        value_date=None,
        amount=amount,
        currency=currency,
        merchant=transaction.get("merchantInformation", {}).get("merchantName")
        or transaction.get("descriptions", {}).get("display"),
        description=transaction.get("descriptions", {}).get("original"),
        category=transaction.get("categories", {}).get("pfm", {}).get("name"),
    )
