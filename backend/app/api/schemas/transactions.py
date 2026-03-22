import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel


class TransactionResponse(BaseModel):
    id: uuid.UUID
    bank_account_id: uuid.UUID
    booked_at: date
    value_date: date | None = None
    amount: Decimal
    currency: str
    merchant: str | None = None
    raw_description: str | None = None
    normalized_category: str | None = None
    is_essential: bool
    source: str

    model_config = {"from_attributes": True}


class SyncRequest(BaseModel):
    date_from: date | None = None
    date_to: date | None = None


class SyncResponse(BaseModel):
    transactions_synced: int
