import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.transactions import SyncResponse, TransactionResponse
from app.db.session import get_db
from app.services.bank_account_service import BankAccountService
from app.services.bank_sync import sync_transactions_for_user
from app.services.csv_import import import_csv_transactions
from app.services.transaction_service import TransactionService
from app.services.user_service import UserService

router = APIRouter()


@router.get("/{user_id}", response_model=list[TransactionResponse])
async def list_transactions(
    user_id: uuid.UUID,
    from_date: date | None = Query(default=None),
    to_date: date | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    txn_svc = TransactionService(db)
    transactions = await txn_svc.list_for_user(
        user_id, from_date=from_date, to_date=to_date
    )
    return transactions


@router.post("/{user_id}/sync", response_model=SyncResponse)
async def sync_transactions(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    count = await sync_transactions_for_user(db, user_id)
    await db.commit()
    return SyncResponse(transactions_synced=count)


class CSVUploadResponse(BaseModel):
    transactions_imported: int


@router.post("/{user_id}/import-csv", response_model=CSVUploadResponse)
async def import_csv(
    user_id: uuid.UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Import transactions from a Danish bank CSV export (Danske Bank, Nordea)."""
    user_svc = UserService(db)
    user = await user_svc.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Ensure user has at least one bank account to attach transactions to
    account_svc = BankAccountService(db)
    accounts = await account_svc.list_for_user(user_id)
    if not accounts:
        # Create a CSV import placeholder account
        from app.services.bank_connection_service import BankConnectionService

        conn_svc = BankConnectionService(db)
        connection = await conn_svc.create(
            user_id=user_id,
            institution_id="csv-import",
            requisition_id=f"csv-{user_id}",
            provider="csv",
        )
        account = await account_svc.upsert_from_provider(
            user_id=user_id,
            connection_id=connection.id,
            provider_account_id=f"csv-account-{user_id}",
            name="CSV Import",
            iban_masked=None,
            currency="DKK",
        )
        await db.flush()
    else:
        account = accounts[0]

    # Read and decode CSV
    raw = await file.read()
    # Try common encodings for Danish bank exports
    for encoding in ("utf-8-sig", "utf-8", "iso-8859-1", "cp1252"):
        try:
            csv_content = raw.decode(encoding)
            break
        except (UnicodeDecodeError, ValueError):
            continue
    else:
        raise HTTPException(status_code=400, detail="Could not decode CSV file")

    count = await import_csv_transactions(db, user_id, account.id, csv_content)
    await db.commit()
    return CSVUploadResponse(transactions_imported=count)
