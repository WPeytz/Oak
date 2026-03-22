import uuid
from abc import ABC, abstractmethod
from datetime import date
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.transaction import Transaction


class TransactionServiceBase(ABC):
    @abstractmethod
    async def list_for_user(
        self,
        user_id: uuid.UUID,
        from_date: date | None = None,
        to_date: date | None = None,
    ) -> list[Transaction]: ...

    @abstractmethod
    async def list_for_account(
        self, account_id: uuid.UUID
    ) -> list[Transaction]: ...

    @abstractmethod
    async def upsert_from_provider(
        self,
        user_id: uuid.UUID,
        bank_account_id: uuid.UUID,
        provider_transaction_id: str,
        booked_at: date,
        amount: Decimal,
        currency: str,
        merchant: str | None,
        raw_description: str | None,
        raw_category: str | None,
        value_date: date | None = None,
    ) -> Transaction: ...

    @abstractmethod
    async def bulk_upsert(
        self,
        user_id: uuid.UUID,
        bank_account_id: uuid.UUID,
        records: list[dict],
    ) -> int: ...


class TransactionService(TransactionServiceBase):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_for_user(
        self,
        user_id: uuid.UUID,
        from_date: date | None = None,
        to_date: date | None = None,
    ) -> list[Transaction]:
        stmt = select(Transaction).where(Transaction.user_id == user_id)
        if from_date:
            stmt = stmt.where(Transaction.booked_at >= from_date)
        if to_date:
            stmt = stmt.where(Transaction.booked_at <= to_date)
        stmt = stmt.order_by(Transaction.booked_at.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def list_for_account(
        self, account_id: uuid.UUID
    ) -> list[Transaction]:
        result = await self.db.execute(
            select(Transaction)
            .where(Transaction.bank_account_id == account_id)
            .order_by(Transaction.booked_at.desc())
        )
        return list(result.scalars().all())

    async def upsert_from_provider(
        self,
        user_id: uuid.UUID,
        bank_account_id: uuid.UUID,
        provider_transaction_id: str,
        booked_at: date,
        amount: Decimal,
        currency: str,
        merchant: str | None,
        raw_description: str | None,
        raw_category: str | None,
        value_date: date | None = None,
    ) -> Transaction:
        result = await self.db.execute(
            select(Transaction).where(
                Transaction.provider_transaction_id == provider_transaction_id
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            return existing

        txn = Transaction(
            user_id=user_id,
            bank_account_id=bank_account_id,
            provider_transaction_id=provider_transaction_id,
            booked_at=booked_at,
            amount=amount,
            currency=currency,
            merchant=merchant,
            raw_description=raw_description,
            raw_category=raw_category,
            value_date=value_date,
            source="tink",
        )
        self.db.add(txn)
        await self.db.flush()
        return txn

    async def bulk_upsert(
        self,
        user_id: uuid.UUID,
        bank_account_id: uuid.UUID,
        records: list[dict],
    ) -> int:
        count = 0
        for rec in records:
            result = await self.db.execute(
                select(Transaction).where(
                    Transaction.provider_transaction_id
                    == rec["provider_transaction_id"]
                )
            )
            if result.scalar_one_or_none() is None:
                txn = Transaction(
                    user_id=user_id,
                    bank_account_id=bank_account_id,
                    source=rec.get("source", "tink"),
                    **{
                        k: v
                        for k, v in rec.items()
                        if k not in ("source",)
                    },
                )
                self.db.add(txn)
                count += 1
        await self.db.flush()
        return count
