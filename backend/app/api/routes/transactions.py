import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.transactions import SyncResponse, TransactionResponse
from app.db.session import get_db
from app.services.bank_sync import sync_transactions_for_user
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
