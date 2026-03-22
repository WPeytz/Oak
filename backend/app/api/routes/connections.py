import uuid
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.connections import (
    ConnectionResponse,
    ConnectionStatusResponse,
    CreateConnectionRequest,
    InstitutionResponse,
)
from app.config import settings
from app.db.session import get_db
from app.providers.tink import get_banking_provider
from app.services.bank_connection_service import BankConnectionService
from app.services.bank_sync import sync_accounts_for_connection
from app.services.user_service import UserService

router = APIRouter()


def _build_redirect_url(connection_id: uuid.UUID) -> str:
    """Build the URL Tink redirects to after bank auth."""
    return f"{settings.base_url}/api/connections/callback?ref={connection_id}"


def _build_ios_deeplink(connection_id: uuid.UUID, status: str) -> str:
    """Build the oak:// deep link to bounce the user back into the app."""
    params = urlencode({"connection_id": str(connection_id), "status": status})
    return f"{settings.ios_callback_scheme}://bank-callback?{params}"


@router.get("/institutions", response_model=list[InstitutionResponse])
async def list_institutions(country: str = Query(default="DK", min_length=2, max_length=2)):
    provider = get_banking_provider()
    institutions = await provider.list_institutions(country)
    return [
        InstitutionResponse(
            id=inst.id,
            name=inst.name,
            logo_url=inst.logo_url,
            countries=inst.countries,
        )
        for inst in institutions
    ]


@router.post("/{user_id}", response_model=ConnectionResponse, status_code=201)
async def create_connection(
    user_id: uuid.UUID,
    body: CreateConnectionRequest,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    conn_svc = BankConnectionService(db)

    # Create a placeholder connection to get its ID for the redirect URL
    provider = get_banking_provider()

    # We need the connection ID in the redirect URL, so create a temporary
    # requisition ID, then update it after the provider call.
    # Simpler approach: create connection first with a placeholder, then update.
    connection = await conn_svc.create(
        user_id=user_id,
        institution_id=body.institution_id,
        requisition_id="pending",  # will be updated
    )
    await db.flush()

    redirect_url = _build_redirect_url(connection.id)

    requisition = await provider.create_requisition(
        redirect_url=redirect_url,
        institution_id=body.institution_id,
        reference=str(user_id),
    )

    # Update connection with real requisition ID
    connection.requisition_id = requisition.id

    # In sandbox mode the requisition is immediately linked
    if requisition.status == "linked":
        await conn_svc.update_status(connection.id, "linked")
        await sync_accounts_for_connection(
            db, user_id, connection.id, requisition.id
        )
        await conn_svc.mark_synced(connection.id)

    await db.commit()
    await db.refresh(connection)

    # The authorization_url is the Tink Link URL the user must visit
    auth_url = None
    if requisition.status != "linked":
        auth_url = requisition.redirect_url

    return ConnectionResponse(
        id=connection.id,
        institution_id=connection.institution_id,
        requisition_id=connection.requisition_id,
        status=connection.status,
        authorization_url=auth_url,
        created_at=connection.created_at,
        last_synced_at=connection.last_synced_at,
    )


@router.get("/callback")
async def bank_auth_callback(
    ref: uuid.UUID = Query(..., description="Connection ID"),
    db: AsyncSession = Depends(get_db),
):
    """Tink redirects here after user completes bank authorization.

    We check the credentials status, sync accounts if linked, then redirect
    the user back to the iOS app via the oak:// deep link scheme.
    """
    conn_svc = BankConnectionService(db)
    connection = await conn_svc.get_by_id(ref)

    if not connection:
        # Still redirect to app with error status
        return RedirectResponse(
            url=_build_ios_deeplink(ref, "error"),
            status_code=302,
        )

    provider = get_banking_provider()
    requisition = await provider.get_requisition(connection.requisition_id)

    if requisition.status == "linked":
        await conn_svc.update_status(connection.id, "linked")
        await sync_accounts_for_connection(
            db, connection.user_id, connection.id, connection.requisition_id
        )
        await conn_svc.mark_synced(connection.id)
        await db.commit()
        return RedirectResponse(
            url=_build_ios_deeplink(connection.id, "success"),
            status_code=302,
        )

    if requisition.status in ("expired", "revoked"):
        status = requisition.status
        await conn_svc.update_status(connection.id, status)
        await db.commit()
        return RedirectResponse(
            url=_build_ios_deeplink(connection.id, status),
            status_code=302,
        )

    # Still pending (user may have cancelled at the bank) — redirect with pending
    return RedirectResponse(
        url=_build_ios_deeplink(connection.id, "pending"),
        status_code=302,
    )


@router.get("/{user_id}/{connection_id}/status", response_model=ConnectionStatusResponse)
async def poll_connection_status(
    user_id: uuid.UUID,
    connection_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    conn_svc = BankConnectionService(db)
    connection = await conn_svc.get_by_id(connection_id)
    if not connection or connection.user_id != user_id:
        raise HTTPException(status_code=404, detail="Connection not found")

    # If still pending, check with the provider
    if connection.status == "pending":
        provider = get_banking_provider()
        requisition = await provider.get_requisition(connection.requisition_id)

        if requisition.status == "linked":
            await conn_svc.update_status(connection.id, "linked")
            accounts_synced = await sync_accounts_for_connection(
                db, user_id, connection.id, connection.requisition_id
            )
            await conn_svc.mark_synced(connection.id)
            await db.commit()
            return ConnectionStatusResponse(
                id=connection.id,
                status="linked",
                accounts_synced=accounts_synced,
            )
        elif requisition.status in ("expired", "revoked"):
            status = requisition.status
            await conn_svc.update_status(connection.id, status)
            await db.commit()
            return ConnectionStatusResponse(id=connection.id, status=status)

    # Already linked — count accounts
    from app.services.bank_account_service import BankAccountService

    account_svc = BankAccountService(db)
    accounts = await account_svc.list_for_connection(connection.id)

    return ConnectionStatusResponse(
        id=connection.id,
        status=connection.status,
        accounts_synced=len(accounts),
    )


@router.get("/{user_id}", response_model=list[ConnectionResponse])
async def list_connections(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    conn_svc = BankConnectionService(db)
    connections = await conn_svc.list_for_user(user_id)
    return [
        ConnectionResponse(
            id=c.id,
            institution_id=c.institution_id,
            requisition_id=c.requisition_id,
            status=c.status,
            created_at=c.created_at,
            last_synced_at=c.last_synced_at,
        )
        for c in connections
    ]
